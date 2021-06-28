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
import Hash "mo:base/Hash";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Cycles = "mo:base/ExperimentalCycles";
import Token "./ic-token/erc20/src/token";

shared(msg) actor class TokenRegistry() {
	
	public type TokenInfo = {
		id: Nat;
		name: Text;
		symbol: Text;
		decimals: Nat64;
		totalSupply: Nat64;
		owner: Principal;
		canisterId: Principal;
	};
	private stable var _owner: Principal = msg.caller;
	private stable var numTokens: Nat = 0;
	private stable var cyclesPerToken: Nat = 2000000000000; // 2 trillion cycles for each token canister
	private stable var maxNumTokens: Nat = 500;
	private stable var maxNumTokensPerId: Nat = 1;
	// TODO: make this upgradable
	private var tokens = HashMap.HashMap<Nat, TokenInfo>(0, Nat.equal, Hash.hash);
	private var cid2Token = HashMap.HashMap<Principal, TokenInfo>(0, Principal.equal, Principal.hash);
	private var userTokenNum = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

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
        update_settings: shared(canister_id: Principal, settings: CanisterSettings) -> async ();
        install_code: shared(params: InstallCodeParams) -> async ();
        canister_status: query(canister_id: CanisterId) -> async CanisterStatus;
    };
    let IC: ICActor = actor("aaaaa-aa");

	public shared(msg) func createToken(name: Text, symbol: Text, decimals: Nat64, totalSupply: Nat64): async Principal {
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
		Cycles.add(cyclesPerToken);
		let token = await Token.Token(name, symbol, decimals, totalSupply, msg.caller);
		let cid = Principal.fromActor(token);
		let info: TokenInfo = {
			id = numTokens;
			name = name;
			symbol = symbol;
			decimals = decimals;
			totalSupply = totalSupply;
			owner = msg.caller;
			canisterId = cid;
		};
		tokens.put(numTokens, info);
		cid2Token.put(cid, info);
		numTokens += 1;
		userTokenNum.put(msg.caller, userTokenCount + 1);
		return cid;
	};

	public shared(msg) func setController(canisterId: Principal): async Bool {
		switch(cid2Token.get(canisterId)) {
			case(?info) {
				assert(msg.caller == info.owner);
				let controllers: ?[Principal] = ?[msg.caller];
				let settings: CanisterSettings = {
					controllers = controllers;
					compute_allocation = null;
					memory_allocation = null;
					freezing_threshold = null;
				};
				await IC.update_settings(canisterId, settings);
				return true;
			};
			case(_) { return false };
		}
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

	public query func getUserTokenList(user: Principal): async [TokenInfo] {
		var tokenList: [TokenInfo] = [];
		for((id, token) in tokens.entries()) {
			if(token.owner == user) {
				tokenList := Array.append<TokenInfo>(tokenList, [token]);
			};
		};
		tokenList
	};

	// public query func getTokenCID(id: Nat): async ?Principal {
	// 	switch(tokens.get(id)) {
	// 		case(?info) {
	// 			info.canisterId
	// 		};
	// 		case(_) { null };
	// 	}
	// };

	public query func getTokenInfoById(id: Nat): async ?TokenInfo {
		tokens.get(id)
	};

	public query func getTokenInfoByCID(cid: Principal): async ?TokenInfo {
		cid2Token.get(cid)
	};
};
