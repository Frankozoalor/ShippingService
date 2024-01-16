// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ShippingService is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes32 public constant WAREHOUSE_MANAGER = keccak256("WAREHOUSE_MANAGER");

    uint256 public MIN_OTP = 999;

    uint256 public MAX_OTP = 10000;

    uint256 private dispatchOTP;

    uint256 public orderId;

    error OrderNotInQueue();
    error WrongCustomerAddress();

    event BatchorderShipped(uint256 orderNo, address customeraddress);

    event orderCreated(
        address customeraddress,
        string ResidenceAddress,
        string item,
        uint256 Quantity
    );
    event orderShipped(
        address customeraddress,
        string ResidenceAddress,
        string item,
        uint256 Quantity
    );
    event orderAccepted(
        address customeraddress,
        string ResidenceAddress,
        string item,
        uint256 Quantity
    );

    enum ShipmentStatus {
        NoOrder,
        Queued,
        Shipped,
        Delivered
    }

    struct Order {
        address CustomerAddress;
        string ResidenceAddress;
        string item;
        uint256 Quantity;
        ShipmentStatus shipmentstatus_;
    }

    constructor() {
        _grantRole(WAREHOUSE_MANAGER, msg.sender);
    }

    mapping(address customerAddress => mapping(uint256 orderId => Order))
        public orderByCustomer;

    mapping(address customerAddress => uint256 successfulDeliveries)
        public DelieveredByAddress;

    function createOrder(
        string memory _item,
        string memory _residenceAddress,
        uint256 _quantity
    ) external {
        uint256 Id_ = orderId++;
        Order storage order = orderByCustomer[msg.sender][Id_];
        order.CustomerAddress = msg.sender;
        order.item = _item;
        order.Quantity = _quantity;
        order.ResidenceAddress = _residenceAddress;
        order.shipmentstatus_ = ShipmentStatus.Queued;

        emit orderCreated(msg.sender, _residenceAddress, _item, _quantity);
    }

    //This function inititates the shipment
    function shipWithPin(
        uint256 id_,
        address customerAddress,
        uint256 pin
    ) public onlyRole(WAREHOUSE_MANAGER) {
        require(
            pin == dispatchOTP && pin > MIN_OTP && pin < MAX_OTP,
            "Invalid Pin"
        );
        Order storage order = orderByCustomer[customerAddress][id_];
        if (order.CustomerAddress != customerAddress)
            revert WrongCustomerAddress();
        if (order.shipmentstatus_ != ShipmentStatus.Queued)
            revert OrderNotInQueue();
        order.shipmentstatus_ = ShipmentStatus.Shipped;

        emit orderShipped(
            msg.sender,
            order.ResidenceAddress,
            order.item,
            order.Quantity
        );
    }

    function shipBatchWithPin(
        uint256[] memory id_,
        address customerAddress,
        uint256 pin
    ) internal onlyRole(WAREHOUSE_MANAGER) {
        require(
            pin == dispatchOTP && pin > MIN_OTP && pin < MAX_OTP,
            "Invalid Pin"
        );
        uint256[] memory noOfOrder = new uint256[](id_.length + 1);
        for (uint256 i = 1; i < noOfOrder.length; i++) {
            uint256 orderNo = id_[i];
            if (
                orderByCustomer[customerAddress][orderNo].shipmentstatus_ ==
                ShipmentStatus.Queued
            ) {
                orderByCustomer[customerAddress][orderNo]
                    .shipmentstatus_ = ShipmentStatus.Shipped;
                emit BatchorderShipped(orderNo, msg.sender);
            } else {
                revert OrderNotInQueue();
            }
        }
    }

    //This function acknowlegdes the acceptance of the delivery
    function acceptOrder(uint256 id_, uint pin) public {
        Order storage order = orderByCustomer[msg.sender][id_];
        require(pin == dispatchOTP, "Invalid Pin");
        require(order.CustomerAddress == msg.sender, "Caller not owner");
        require(
            order.shipmentstatus_ == ShipmentStatus.Shipped,
            "Order not shipped"
        );
        dispatchOTP = 0;
        order.shipmentstatus_ = ShipmentStatus.Delivered;
        DelieveredByAddress[msg.sender]++;
        delete orderByCustomer[msg.sender][id_];
        emit orderAccepted(
            msg.sender,
            order.ResidenceAddress,
            order.item,
            order.Quantity
        );
    }

    //This function outputs the status of the delivery
    function checkStatus(uint256 id_) public view returns (ShipmentStatus) {
        Order storage order = orderByCustomer[msg.sender][id_];
        if (
            order.shipmentstatus_ != ShipmentStatus.Queued &&
            order.shipmentstatus_ != ShipmentStatus.Shipped &&
            order.shipmentstatus_ != ShipmentStatus.Delivered
        ) {
            return ShipmentStatus.NoOrder;
        } else {
            return order.shipmentstatus_;
        }
    }

    //This function outputs the total number of successful deliveries
    function totalCompletedDeliveries(
        address customerAddress
    ) public view returns (uint256) {
        return DelieveredByAddress[customerAddress];
    }

    function generateRandomOTP() private view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)
            )
        );
        return (randomNumber % 9000) + 1000;
    }

    function requestOTP() private onlyRole(WAREHOUSE_MANAGER) {
        require(dispatchOTP == 0, "Previous OTP not used");
        dispatchOTP = generateRandomOTP();
    }
}
