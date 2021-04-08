import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Token "./token";

shared(msg) actor class TokenRegistry() {
	
	public type TokenInfo = {
		id: Nat;
		name: Text;
		symbol: Text;
		decimals: Nat;
		totalSupply: Nat;
		owner: Principal;
		canisterId: Principal;
	};
	private var numTokens: Nat = 0;
	private var tokens = HashMap.HashMap<Nat, TokenInfo>(0, Nat.equal, Hash.hash);
	private var cid2Token = HashMap.HashMap<Principal, TokenInfo>(0, Principal.equal, Principal.hash);

	public shared(msg) func createToken(name: Text, symbol: Text, decimals: Nat, totalSupply: Nat): async Principal {
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
		return cid;
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
