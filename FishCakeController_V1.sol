// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

library TransferHelper {
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }
}

contract FishCakeController is Context {
    address public adminAddr  = address(0x370Ac82Fc21E151EE8C124DcF4bd36D90E450551);

    address constant public FccTokenAddr = address(0xF99fe67aE24dEb13A39bDd286f48e67433C10606);

    struct ActivityInfo {
        uint256 activityId;       
        address businessAccount;       
        string businessName;     
        string activityContent;     
        string latitudeLongitude;   
        uint256 activityCreateTime;       
        uint256 activityDeadLine;       
        uint8 dropType;     
        uint256 dropNumber;     
        uint256 minDropAmt;     
        uint256 maxDropAmt;    
        uint256 alreadyDropAmts;        
        uint256 alreadyDropNumber;        
        uint8 activityStatus;     
    }
    ActivityInfo[] public activityInfoArrs; 

    struct DropInfo {
        uint256 activityId;       
        address userAccount;       
        uint256 dropTime;       
        uint256 dropAmt;     
    }
    DropInfo[] public dropInfoArrs; // 所有获奖数组
    mapping(uint256 => mapping(address => bool)) public activityDropedToAccount; 


    function setParam(address _adminAddr) public {
        require(_msgSender() == adminAddr, "Must From Admin.");
        adminAddr = _adminAddr;
    }

    
    function activityAdd(
            string memory _businessName, string memory _activityContent, string memory _latitudeLongitude, uint256 _activityDeadLine, 
            uint256 _totalDropAmts, uint8 _dropType, uint256 _dropNumber, uint256 _minDropAmt, uint256 _maxDropAmt) public returns(bool _ret, uint256 _activityId) {

        require(_dropType == 2 || _dropType == 1, "Drop Type Error.");
        require(_totalDropAmts > 0, "Drop Amount Error.");

        require(_totalDropAmts == _maxDropAmt * _dropNumber, "Drop Number Not Meet Total Drop Amounts.");

        
        TransferHelper.safeTransferFrom(FccTokenAddr, _msgSender(), address(this), _totalDropAmts);     

        ActivityInfo memory ai = ActivityInfo({
            activityId: activityInfoArrs.length + 1, 
            businessAccount: _msgSender(),
            businessName: _businessName,
            activityContent: _activityContent,
            latitudeLongitude: _latitudeLongitude,
            activityCreateTime: block.timestamp,
            activityDeadLine: _activityDeadLine,
            dropType: _dropType,
            dropNumber: _dropNumber,
            minDropAmt: _minDropAmt,
            maxDropAmt: _maxDropAmt,
            alreadyDropAmts: 0,
            alreadyDropNumber: 0,
            activityStatus: 1
        });
        activityInfoArrs.push(ai);

        _ret = true;
        _activityId = ai.activityId;
    }


    event ActivityFinish(uint256 indexed _activityId);
    
    function activityFinish(uint256 _activityId) public returns(bool _ret) {

        ActivityInfo storage ai = activityInfoArrs[_activityId - 1];

        require(ai.businessAccount == _msgSender(), "Not The Owner.");
        require(ai.activityStatus == 1, "Activity Status Error.");

        ai.activityStatus = 2;

        if (ai.maxDropAmt * ai.dropNumber > ai.alreadyDropAmts) {
            TransferHelper.safeTransfer(FccTokenAddr, _msgSender(), ai.maxDropAmt * ai.dropNumber - ai.alreadyDropAmts);     
        } 

        emit ActivityFinish(_activityId);      

        _ret = true;
    }


    
    function drop(uint256 _activityId, address _userAccount, uint256 _dropAmt) external returns(bool _ret) {
        require(activityDropedToAccount[_activityId][_userAccount] == false, "User Has Droped.");

        ActivityInfo storage ai = activityInfoArrs[_activityId - 1];

        require(ai.activityStatus == 1, "Activity Status Error.");
        require(ai.businessAccount == _msgSender(), "Not The Owner.");

        if (ai.dropType == 2) {
            require(_dropAmt <= ai.maxDropAmt && _dropAmt >= ai.minDropAmt, "Drop Amount Error.");
        } else {
            _dropAmt = ai.maxDropAmt;
        }

        require(ai.dropNumber > ai.alreadyDropNumber, "Exceeded the number of rewards.");
        require(ai.maxDropAmt * ai.dropNumber >= _dropAmt + ai.alreadyDropAmts, "The reward amount has been exceeded.");

        TransferHelper.safeTransfer(FccTokenAddr, _userAccount, _dropAmt);

        activityDropedToAccount[_activityId][_userAccount] = true;


        DropInfo memory di = DropInfo({
            activityId: _activityId, 
            userAccount: _userAccount,
            dropTime: block.timestamp,
            dropAmt: _dropAmt
        });
        dropInfoArrs.push(di);

        ai.alreadyDropAmts += _dropAmt;
        ai.alreadyDropNumber ++;

        _ret = true;
    }
}