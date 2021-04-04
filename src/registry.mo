import HashMap "mo:base/HashMap";
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
	public stable var numTokens = 0;
	private stable var tokens = HashMap.HashMap<Nat, TokenInfo>(0, Nat.equal, Hash.hash);
	private stable var cid2Token = HashMap.HashMap<Principal, TokenInfo>(0, Principal.equal, Principal.hash);

	public shared(msg) func createToken(name: Text, symbol: Text, decimals: Nat, totalSupply: Nat): async Principal {
		let token = await Token.Token(name, symbol, decimals, totalSupply, msg.caller);
		let cid = Principal.fromActor(token);
		let info: TokenInfo = {
			id = numPairs;
			name = name;
			symbol = symbol;
			decimals = decimals;
			totalSupply = totalSupply;
			owner = msg.caller;
			canisterId = cid;
		};
		tokens.put(numPairs, info);
		cid2Token.put(cid, info);
		numPairs += 1;
		return cid;
	};

	public query func getTokenCID(id: Nat): async ?Principal {
		switch(tokens.get(id)) {
			case(?info) {
				info.canisterId
			};
			case(_) { null }
		}
	}

	public query func getTokenInfoById(id: Nat): async ?TokenInfo {
		tokens.get(id)
	}

	public query func getTokenInfoByCID(cid: Principal): async ?TokenInfo {
		cid2Token.get(cid)
	}
};
