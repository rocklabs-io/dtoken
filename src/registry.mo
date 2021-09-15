/**
 * Module     : registry.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Order "mo:base/Order";
import Hash "mo:base/Hash";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Cycles = "mo:base/ExperimentalCycles";
import Token "./ic-token/motoko/src/token";

shared(msg) actor class TokenRegistry(owner: Principal, _feeTokenId: Principal, _fee: Nat) = this {
    type TxReceipt = Result.Result<Nat, {
        #InsufficientBalance;
        #InsufficientAllowance;
    }>;
    type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat8;
        totalSupply : Nat;
        owner : Principal;
        fee : Nat;
    };
    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #transferFrom;
        #approve;
    };
    public type TxRecord = {
        caller: ?Principal;
        op: Operation;
        index: Nat;
        from: Principal;
        to: Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };
    public type TokenInfo = {
        index: Nat;
        logo: Text;
        name: Text;
        symbol: Text;
        decimals: Nat8;
        totalSupply: Nat;
        owner: Principal;
        fee: Nat;
        canisterId: Principal;
        timestamp: Int;
    };
    public type TokenActor = actor {
        allowance: shared (owner: Principal, spender: Principal) -> async Nat;
        approve: shared (spender: Principal, value: Nat) -> async TxReceipt;
        balanceOf: (owner: Principal) -> async Nat;
        decimals: () -> async Nat;
        name: () -> async Text;
        symbol: () -> async Text;
        totalSupply: () -> async Nat;
        getMetadata: () -> async Metadata;
        getTransaction: (index: Nat) -> async TxRecord;
        transfer: shared (to: Principal, value: Nat) -> async TxReceipt;
        transferFrom: shared (from: Principal, to: Principal, value: Nat) -> async TxReceipt;
    };
    private stable var _owner: Principal = owner;
    private stable var numTokens: Nat = 0;
    private stable var cyclesPerToken: Nat = 2000000000000; // 2 trillion cycles for each token canister
    private stable var maxNumTokens: Nat = 100;
    private stable var maxNumTokensPerId: Nat = 2;
    private stable var feeTokenId: Principal = _feeTokenId;
    private stable var fee: Nat = _fee;

    private stable var tokenEntries : [(Principal, TokenInfo)] = [];
    private stable var userTokenNumEntries : [(Principal, Nat)] = [];
    private var tokens = HashMap.HashMap<Principal, TokenInfo>(0, Principal.equal, Principal.hash);
    private var userTokenNum = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

    public type Stats = {
        owner: Principal;
        numTokens: Nat;
        cyclesPerToken: Nat;
        maxNumTokens: Nat;
        maxNumTokensPerId: Nat;
        cycles: Nat;
        feeTokenId: Principal;
        fee: Nat;
    };

    type CanisterSettings = {
        controllers : ?[Principal];
        compute_allocation : ?Nat;
        memory_allocation : ?Nat;
        freezing_threshold : ?Nat;
    };
    type CanisterId = {
        canister_id: Principal;
    };
    type InstallMode = {
        #install;
        #reinstall;
        #upgrade;
    };
    type InstallCodeParams = {
        mode: InstallMode;
        canister_id: Principal;
        wasm_module: Blob;
        arg: Blob;
    };
    type UpdateSettingsParams = {
        canister_id: Principal;
        settings: CanisterSettings;
    };
    type Status = {
        #running;
        #stopping;
        #stopped;
    };
    type CanisterStatus = {
        status: Status;
        settings: CanisterSettings;
        module_hash: ?Blob;
        memory_size: Nat;
        cycles: Nat;
    };
    public type ICActor = actor {
        create_canister: shared(settings: ?CanisterSettings) -> async CanisterId;
        update_settings: shared(params: UpdateSettingsParams) -> async ();
        install_code: shared(params: InstallCodeParams) -> async ();
        canister_status: query(canister_id: CanisterId) -> async CanisterStatus;
    };
    let IC: ICActor = actor("aaaaa-aa");

    system func preupgrade() {
        tokenEntries := Iter.toArray(tokens.entries());
        userTokenNumEntries := Iter.toArray(userTokenNum.entries());
    };

    system func postupgrade() {
        tokens := HashMap.fromIter<Principal, TokenInfo>(tokenEntries.vals(), 1, Principal.equal, Principal.hash);
        tokenEntries := [];
        userTokenNum := HashMap.fromIter<Principal, Nat>(userTokenNumEntries.vals(), 1, Principal.equal, Principal.hash);
        userTokenNumEntries := [];
    };

    public shared(msg) func createToken(
        logo: Text, 
        name: Text, 
        symbol: Text, 
        decimals: Nat8, 
        totalSupply: Nat,
        fee: Nat
        ): async Principal {
        if(numTokens >= maxNumTokens) {
            throw Error.reject("Exceeds max number of tokens");
        };
        var userTokenCount: Nat = 0;
        switch(userTokenNum.get(msg.caller)) {
            case (?tokenCount) {
                if(tokenCount > maxNumTokensPerId) {
                    throw Error.reject("exceeds max number of tokens per user");
                };
                userTokenCount := tokenCount;
            };
            case (_) {};
        };
        // charge fee
        let feeToken: TokenActor = actor(Principal.toText(feeTokenId));
        switch(await feeToken.transferFrom(msg.caller, Principal.fromActor(this), fee)) {
            case(#ok(txid)) {};
            case(#err(e)) { 
                throw Error.reject("fee transfer failed");
            };
        };
        // create token canister
        Cycles.add(cyclesPerToken);
        let token = await Token.Token(logo, name, symbol, decimals, totalSupply, msg.caller, fee);
        let cid = Principal.fromActor(token);
        let info: TokenInfo = {
            index = numTokens;
            logo = logo;
            name = name;
            symbol = symbol;
            decimals = decimals;
            totalSupply = totalSupply;
            owner = msg.caller;
            fee = fee;
            canisterId = cid;
            timestamp = Time.now();
        };
        tokens.put(cid, info);
        numTokens += 1;
        userTokenNum.put(msg.caller, userTokenCount + 1);
        return cid;
    };

    public shared(msg) func setController(canisterId: Principal): async Bool {
        switch(tokens.get(canisterId)) {
            case(?info) {
                assert(msg.caller == info.owner or msg.caller == _owner);
                let controllers: ?[Principal] = ?[msg.caller, Principal.fromActor(this)];
                let settings: CanisterSettings = {
                    controllers = controllers;
                    compute_allocation = null;
                    memory_allocation = null;
                    freezing_threshold = null;
                };
                let params: UpdateSettingsParams = {
                    canister_id = canisterId;
                    settings = settings;
                };
                await IC.update_settings(params);
                return true;
            };
            case(_) { return false };
        }
    };

    public shared(msg) func getTokenCanisterStatus(canister_id: Principal): async ?CanisterStatus {
        switch(tokens.get(canister_id)) {
            case(?info) {
                let param: CanisterId = {
                    canister_id = canister_id;
                };
                let status = await IC.canister_status(param);
                return ?status;
            };
            case(_) {return null};
        }
    };

    public shared(msg) func claimFee(): async TxReceipt {
        assert(msg.caller == _owner);
        let feeToken: TokenActor = actor(Principal.toText(feeTokenId));
        let balance: Nat = await feeToken.balanceOf(Principal.fromActor(this));
        return await feeToken.transfer(msg.caller, balance);
    };

    public shared(msg) func setFee(newFee: Nat): async Bool {
        assert(msg.caller == _owner);
        fee := newFee;
        return true;
    };

    public shared(msg) func modifyTokenInfo(info: TokenInfo): async Bool {
        assert(msg.caller == _owner);
        tokens.put(info.canisterId, info);
        return true;
    };

    public shared(msg) func addToken(tid: Principal): async Bool {
        let token: TokenActor = actor(Principal.toText(tid));
        let metadata: Metadata = await token.getMetadata();
        let tx: TxRecord = await token.getTransaction(0);
        let info: TokenInfo = {
            index = numTokens;
            logo = metadata.logo;
            name = metadata.name;
            symbol = metadata.symbol;
            decimals = metadata.decimals;
            totalSupply = metadata.totalSupply;
            owner = metadata.owner;
            fee = metadata.fee;
            canisterId = tid;
            timestamp = tx.timestamp;
        };
        tokens.put(tid, info);
        numTokens += 1;
        return true;
    };

    public shared(msg) func setNumTokens(n: Nat): async Bool {
        assert(msg.caller == _owner);
        numTokens := n;
        return true;
    };

    public shared(msg) func setMaxTokenNumber(n: Nat) {
        assert(msg.caller == _owner);
        maxNumTokens := n;
    };

    public shared(msg) func setMaxTokenNumberPerUser(n: Nat) {
        assert(msg.caller == _owner);
        maxNumTokensPerId := n;
    };

    public shared(msg) func setCyclesPerToken(n: Nat) {
        assert(msg.caller == _owner);
        cyclesPerToken := n;
    };

    public shared(msg) func setOwner(newOwner: Principal) {
        assert(msg.caller == _owner);
        _owner := newOwner;
    };

    public shared(msg) func removeToken(id: Principal) {
        assert(msg.caller == _owner);
        tokens.delete(id);
    };

    public query func getCyclesBalance(): async Nat {
        return Cycles.balance();
    };

    public query func getTokenCount(): async Nat {
        return numTokens;
    };

    public query func getMaxTokenNumber(): async Nat {
        return maxNumTokens;
    };

    public query func getMaxTokenNumberPerUser(): async Nat {
        return maxNumTokensPerId;
    };

    public query func getStats(): async Stats {
        return {
            owner = _owner;
            numTokens = numTokens;
            cyclesPerToken = cyclesPerToken;
            maxNumTokens = maxNumTokens;
            maxNumTokensPerId = maxNumTokensPerId;
            cycles = Cycles.balance();
            feeTokenId = feeTokenId;
            fee = fee;
        };
    };

    public query func getUserTokenNumber(id: Principal): async Nat {
        switch(userTokenNum.get(id)) {
            case (?num) { return num; };
            case (_) { return 0; };
        }
    };

    public query func getTokenList(): async [TokenInfo] {
        var tokenList: [TokenInfo] = [];
        for((id, token) in tokens.entries()) {
            tokenList := Array.append<TokenInfo>(tokenList, [token]);
        };
        tokenList
    };

    // for paging
    public query func getTokens(start: Nat, num: Nat): async ([TokenInfo], Nat) {
        var tokenList: [TokenInfo] = [];
        func order (a: (Principal, TokenInfo), b: (Principal, TokenInfo)): Order.Order {
            return Nat.compare(a.1.index, b.1.index);
        };
        let temp = Iter.toArray(tokens.entries());
        let sorted = Array.sort(temp, order);
        let limit: Nat = if(start + num > sorted.size()) {
            sorted.size() - start
        } else {
            num
        };
        for (i in Iter.range(0, limit-1)) {
            tokenList := Array.append<TokenInfo>(tokenList, [sorted[i+start].1]);
        };
        (tokenList, sorted.size())
    };

    public query func getTokensByName(t: Text, start: Nat, num: Nat) : async ([TokenInfo], Nat) {
        var temp: [TokenInfo] = [];
        let p : Text.Pattern = #text t;
        for ((id, token) in tokens.entries()) {
            if (Text.contains(token.name, p) or Text.contains(token.symbol, p)) {
                temp := Array.append(temp, [token]);
            };
        };
        var tokenList: [TokenInfo] = [];
        let limit: Nat = if(start + num > temp.size()) {
            temp.size() - start
        } else {
            num
        };
        for (i in Iter.range(0, limit-1)) {
            tokenList := Array.append<TokenInfo>(tokenList, [temp[start+i]])
        };
        (tokenList, temp.size())
    };

    public query func getUserTokenList(user: Principal): async [TokenInfo] {
        var tokenList: [TokenInfo] = [];
        for((index, token) in tokens.entries()) {
            if(token.owner == user) {
                tokenList := Array.append<TokenInfo>(tokenList, [token]);
            };
        };
        tokenList
    };

    public query func getTokenInfo(cid: Principal): async ?TokenInfo {
        tokens.get(cid)
    };
};
