pragma solidity ^0.4.16;

/*

Test case
1, registerOracle -  "0x5148eb77c51b70c68063c48c91fddd936f94d45f","ICBC"  -  "gonganju", "Polistation"
2, requester rules - "1","Saving", ">", "200000"  -   "2", "Desposit", ">", "10000" - "3", "Nationality", "IN", "[CN, JP]" - "4", "RISKRANK", ">", "3"
3, requester requirements - "1", "0x......", "Cybex", "[1,2,3,4]"

*/

contract Kyc {
    address public owner;
    

    struct Rule {
        uint32 ruleId;
        string property;
        string op;
        string value;
    }
    uint32[] ruleIds;

    function Kyc() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
//        require(owner == msg.sender);
        _;
    }
    
    
    mapping(address => Oracle) public oracles;
    address[] oracleList;

    struct Oracle {
        address id;
        string name;
    }

    function registerOracle(address _address, string _name) onlyOwner public returns (bool) {
        oracles[_address] = Oracle(_address, _name);
        oracleList.push(_address);
    }

    // for user
    function getOracleList() public view returns (address[]) {
        return oracleList;
    }

    function getOracleName(address _id) public view returns (string) {
        return oracles[_id].name;
    }

    mapping(address => mapping(uint32 => Request)) requests; // oracle => Request
    mapping(address => uint32[]) requestList;
    struct Request {
        uint32 requestId;
        address requester;
        address oracle;
        string property;
        bytes32 pubKey;
        bytes32 platformId;
        bool expired;
    }
    function request(uint32 requestId, address oracle, string property, bytes32 pubKey, bytes32 platformId) public {
        requests[oracle][requestId] = (Request({
            requestId : requestId,
            requester : msg.sender,
            oracle : oracle,
            property : property,
            pubKey : pubKey,
            platformId : platformId,
            expired : false
            }));
        requestList[oracle].push(requestId);
    }

    function getRuleIds() view public returns (uint32[]) {
        return ruleIds;
    }

    mapping(uint32 => Rule) rules;  // (ruleId => Rule);
    function getRule(uint32 _id) view public returns (uint32 id, string property , string op, string value) {
        Rule rule = rules[_id];
        return (rule.ruleId, rule.property, rule.op, rule.value);
    }
    
    mapping(uint32 => Requirement) requirements; // id => Requirement
    uint32[] requirementIds;
    struct Requirement {
        uint32 id;
        address client;
        string clientName;
        uint32[] ruleIds;
    }
    

    function getRequirementIds() view public returns (uint32[]) {
        return requirementIds;
    }

    function getRequirement(uint32 id) view public returns (address , string , uint32[] ) {
        Requirement r = requirements[id];
        return (r.client, r.clientName, r.ruleIds);
    }

    mapping(address => mapping(uint32 => Response)) responses; // requester => (requstId=>Response)
    mapping(address => uint32[]) responseList; //requster => requestId list
    struct Response {
        uint32 responseId;
        uint32 requestId;
        bytes32 hash;
        string property;
        string encrypedValue;
        uint256 expired;
    }

    // modify by huafu
    function getResponseIds(address requester) view public returns (uint32[]) {
        return responseList[requester];
    }

    function getResponse(address requester, uint32 _id) view public returns (uint32 , uint32 , bytes32 , string , string , uint256 ) {
        Response r= responses[requester][_id];
        return (r.responseId, r.requestId, r.hash, r.property, r.encrypedValue, r.expired);
    }

    // for bank
    function getRequestIds(address requester) view public returns (uint32[]) {
        return requestList[requester];
    }
    
    function getRequest(address requester, uint32 _id) view public returns (uint32 , address , string , bytes32 , bytes32 , bool ) {
        Request r = requests[requester][_id];
        return (r.requestId, r.requester, r.property, r.pubKey, r.platformId, r.expired);
    }

    function oracleCommit(uint32 responseId, uint32 requestId, bytes32 hash, string property, string encrypedValue, uint256 expired) public {
        address requester = requests[msg.sender][requestId].requester;
        responses[requester][responseId] = Response({
            responseId: responseId,
            requestId: requestId,
            hash: hash,
            property: property,
            encrypedValue: encrypedValue,
            expired: expired
        });
        requests[msg.sender][requestId].expired = true;
    }


    // for cybex
    //mapping(bytes32 => Rule) rules;  // (ruleId => Rule);
    function registerRule(uint32 _ruleId, string _property, string _op, string _value) public returns (bool) {
        rules[_ruleId] = Rule({
            ruleId : _ruleId,
            property : _property,
            op : _op,
            value : _value
        });
        ruleIds.push(_ruleId);
        return true;
    }
    
    /*
    mapping(bytes32 => Requirement) requirements; // id => Requirement

    struct Requirement {
        bytes32 id;
        address client;
        string clientName;
        bytes32[] ruleIds;
    }
    */

    function submitRequirements(uint32 id, address client, string clientName, uint32[] ruleIds) public {
        requirements[id] = Requirement(
            {
                id : id,
                client : client,
                clientName : clientName,
                ruleIds : ruleIds
            }
        );
        requirementIds.push(id);
    }
    
    function getValidationIds(address r) view public returns (uint32[]) {
        return validationList[r];
    }

    function getValidationPart1(address r, uint32 _id) view public returns (uint32, address, address, string, uint32[], uint32[], bytes32[]) {
        Validation storage v = validations[r][_id];
        return (
            v.id,
            v.user,
            v.validator,
            v.logic,
            v.requestId,
            v.expired,
            v.hash
            );
    }
    
    function getValidationPart2(address r, uint32 _id) view public returns (string, string, string) {
        Validation v = validations[r][_id];
        return (
            v.properties,
            v.ops,
            v.values
            );
    }
    
    string public userAccount;
    mapping(address=>mapping(uint32 => Validation)) validations; // validator=>(id=>validation);
    mapping(address=>uint32[]) validationList;
    struct Validation {
          uint32 id; // auto inc
          address user;
          address validator;
          string logic;
          uint32[] requestId;
          uint32[] expired;
          bytes32[] hash;
          string properties;
          string ops;
          string values;
    }
    
    // for mpc
    function submitValidation(uint32 id, address user, address validator, string logic, uint32[] requestId, uint32[] expired, bytes32[] hash, string properties, string ops, string values) public {
        validations[validator][id] = Validation({
            id:id,
            user:user,
            validator:validator,
            logic:logic,
            requestId:requestId,
            expired:expired,
            hash:hash,
            properties:properties,
            ops:ops,
            values:values
        });
        validationList[validator].push(id);
        
    }

    
    function submitValidation2(uint32 id, address validator, string user) public {
        validationList[validator].push(id);
        userAccount = user;
    }

}
