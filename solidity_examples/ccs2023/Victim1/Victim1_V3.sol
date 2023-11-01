contract Victim1{
    uint private num;
    address private sender;
    uint private value; 

    function attacked(uint a, address b) public {

        bool sucess = address(msg.sender).call.value(1)("");
        
        if (!sucess){
            throw;
        }

    }
    
    function() external {

    }
}