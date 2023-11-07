contract AttackBridge{
    uint32 private counter;
    bytes4 private func_sig;
    bytes32 private call_data_list;
    uint private flag;


    constructor (string memory func_sig_) public {
    }
   
    function attack1(uint num_, bytes4 func_sig_,  bytes32 call_data_1) public payable {
       
    }

    function attack0(uint num_, bytes4 func_sig_) public payable {
    }

    function call_ (address addr_, bytes4 sig) private returns (bool){
       
    }

    fallback () external payable {
    }
}