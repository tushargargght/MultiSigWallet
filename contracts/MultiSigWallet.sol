// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event Submitted(address indexed owner, address indexed to, uint indexed txId, uint value, bytes data);
    event Confirmed(address indexed owner, uint indexed txId);
    event Revoked(address indexed owner, uint indexed txId);
    event Executed(address indexed executor, uint indexed txId);

    // Owners of the wallet
    address[] public owners;

    // Tx data
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    // Direct address is Owner check
    mapping(address => bool) public isOwner;

    // TxIndex => owner => bool (Map which owners has approved the transaction)
    mapping(uint => mapping(address => bool)) public isConfirm;

    // AllTx's
    Transaction[] public transactions;

    uint public numOfConfirmations;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only Owners can access this functionality");
        _;
    }

    modifier isTransaction(uint txId) {
        require(txId < transactions.length, "Invalid TxId");
        _;
    }

    modifier isNotConfirmed(uint txId) {
        require(transactions[txId].confirmations < numOfConfirmations, "Transaction already confirmed");
        _;
    }

    modifier isNotExecuted(uint txId) {
        require(!transactions[txId].executed, "Tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _numOfConfirmations) {
        require(_owners.length > 0, "Must have >1 owners");
        require(_numOfConfirmations > 0 && _numOfConfirmations <= _owners.length, "Invalid Number of Confirmations");

        for (uint i; i<_owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Cant have Zero address as owner");
            require(!isOwner[owner], "Duplicate Owner not allowed!");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numOfConfirmations = _numOfConfirmations;
    }

    // Receive ether in wallet
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txId = transactions.length;

        transactions.push(Transaction(_to, _value, _data, false, 0));

        emit Submitted(msg.sender, _to, txId, _value, _data);
    }

    function approveTransaction(uint _txId) public onlyOwner isTransaction(_txId) isNotConfirmed(_txId) isNotExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];

        transaction.confirmations++;
        isConfirm[_txId][msg.sender] = true;

        emit Confirmed(msg.sender, _txId);
    }

    function executeTransaction(uint _txId) public isTransaction(_txId) isNotExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];

        require(
            transaction.confirmations >= numOfConfirmations,
            "cannot execute tx"
        );
        
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction execution failed");

        emit Executed(msg.sender, _txId);
    }

    function revokeTransaction(uint _txId) public onlyOwner isTransaction(_txId) isNotExecuted(_txId) {
        require(isConfirm[_txId][msg.sender], "Owner already have not confirmed tx");

        Transaction storage transaction = transactions[_txId];

        transaction.confirmations--;
        isConfirm[_txId][msg.sender] = false;

        emit Revoked(msg.sender, _txId);
    } 

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }

}