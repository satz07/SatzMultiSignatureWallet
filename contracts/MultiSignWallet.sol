//SPDX-LICENSE-IDENTIFIER: MIT

pragma solidity ^0.8.17;

contract MultiSignWallet {

    //EVENTS
    event Deposit(address _address,uint amount, uint balance,string message);
    event ExecuteTx(address owner, uint txIndex,string message);
    event ApproveTx(address owner, uint txIndex,string message);
    event RevokeTx(address owner, uint txIndex,string message);
    event SubmitTx(
        address owner,
        uint txIndex,
        address to,
        uint value,
        bytes data,
        string message
    );

    mapping(address=>bool) public isOwner;

    //VARIABLES AND MAPPINGS
    address[] public owners;
    uint public minConfRequired;

    struct Transaction {
        address to;
        uint val;
        bytes data;
        bool isExecuted;
        uint confirmations;
    }

    Transaction[] public transactions;

    //mapping tx => owner => approval
    mapping(uint=>mapping(address=>bool)) public ownerToApproval;

    //MODIFIERS

    modifier onlyOwner(address _owner){
        require(isOwner[_owner],"Sender is not the Owner");
        _;
    }

    modifier isTxExecuted(uint _txindex){
        require(!transactions[_txindex].isExecuted,"Transaction already executed");
        _;
    }

    constructor (address[] memory _owners,uint _minConfRequired){
        require(_owners.length > 0, "Owners should be atleast 1");
        //require (confRequired > owners.length,"Required confirmations cannot be greater than owners count");

        for (uint i=0; i < _owners.length;i++) {
            require(_owners[i] != address(0),"Owner cannot be empty");
            isOwner[_owners[i]]=true;
            owners.push(_owners[i]);
        }
        minConfRequired = _minConfRequired;
    }

    receive() external payable{
        emit Deposit(msg.sender,msg.value,address(this).balance,"Deposit to contract");
    }

    function SubmitTransaction(address _to,uint _value, bytes memory _data) public returns (bool){

        uint txIndex = transactions.length;

        transactions.push(Transaction(
            _to,
            _value,
            _data,
            false,
            0
        ));
        emit SubmitTx(msg.sender,txIndex,_to,_value,_data,"Submitted a new Transaction");
    }

    function ApproveTransaction(uint _txIndex) public returns (bool) {
        require(!ownerToApproval[_txIndex][msg.sender],"Transaction already approved by the owner");
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations++;
        ownerToApproval[_txIndex] [msg.sender]= true;
        emit ApproveTx(msg.sender,_txIndex,"Transaction approved by the Owner");
        return true;
    }   

    function RevokeTransaction(uint _txIndex) public returns (bool) {
        require(ownerToApproval[_txIndex][msg.sender],"Transaction not approved by the owner");
        Transaction memory transaction = transactions[_txIndex];
        transaction.confirmations--; // CHECK
        ownerToApproval[_txIndex][msg.sender]= false;
        emit RevokeTx(msg.sender,_txIndex,"Transaction Revoked by the Owner");
        return true;
    }

    function ExecuteTransaction(uint _txIndex) public onlyOwner(msg.sender) isTxExecuted(_txIndex) returns (bool) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations>=minConfRequired,"Transaction is not fully confirmed");
        transaction.isExecuted = true;

        (bool success, ) = transaction.to.call{value: transaction.val}(
            transaction.data
        );
        require(success, "tx failed");
        emit ExecuteTx(msg.sender,_txIndex,"Transaction executed");
        return true;
    }

}