//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.16;

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint tokens) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint tokens) external returns (bool);

    function transferFrom( address sender,address recipient,uint tokens) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed owner, address indexed spender, uint tokens);
}



contract MAX is IERC20{

    string public name = "MAX";
    string public symbol = "MAX";
    uint public decimals = 0;
    uint public override totalSupply;

    address public founder;
    mapping(address => uint)  balances;
    
    mapping(address => mapping(address => uint)) allowed;


    constructor(){
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address account) public view override returns (uint){
        return balances[account];
    } 

    function transfer(address recipient, uint tokens) public virtual override returns (bool){
        require(balances[msg.sender] > tokens,"not sufficient balance");

        balances[msg.sender] -= tokens;
        balances[recipient] += tokens;

        emit Transfer(msg.sender, recipient, tokens);
        return true;
    }

    function allowance(address owner, address spender) public override view returns (uint){

        return allowed[owner][spender];
    }

    function approve(address spender, uint tokens) public override returns (bool){
        require(balances[msg.sender] >= tokens);

        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender,spender, tokens);

        return true;
    }

    function transferFrom(address sender,address recipient,uint tokens) public virtual override returns (bool){
        require(allowed[sender][recipient] >= tokens && tokens > 0);
        require(balances[sender] >= tokens);

        balances[sender] -= tokens;
        balances[recipient] += tokens;

        allowed[sender][recipient] -=tokens;
        return true;
    }

}


contract ICO_MAX_ERC20 is MAX{

    address public ICOadmin;
    address payable public depositEOA;
    uint public tokenprice = 0.001 ether; // send 1 ether get 1000 MAX tokens
    uint public hardcap = 600 ether;
    uint public raisedamount;

    uint public ICOstart = block.timestamp; // + 86400 for ico to start one day after contract deployment
    uint public ICOend = ICOstart + 604800; // a week
    uint public minBUY = 0.01 ether;
    uint public maxBUY = 25 ether;
    uint public lockuptime = ICOend + 604800; // a week after icoend

    enum State{beforestart, running, afterend, halted}
    State public ICOstate;

    constructor(address payable _deposit){
        depositEOA = _deposit;
        ICOadmin = msg.sender;
        ICOstate = State.beforestart;
    }

    modifier OnlyOwner(){
        require(msg.sender == ICOadmin,"you aren't admin");
        _;
    }

    function halt() public OnlyOwner {
        ICOstate = State.halted;

    }
    function resume() public OnlyOwner{
        ICOstate = State.running;
    }


    function ICO_state() public view returns(State){
        if(ICOstate == State.halted){
            return State.halted;
        }else if(block.timestamp < ICOstart){
            return State.beforestart;
        }else if(block.timestamp > ICOstart && block.timestamp <= ICOend){
            return State.running;
        }else{
            return State.afterend;
        }
    }

    function depositEOA_change(address payable new_depositEOA) public OnlyOwner{
        depositEOA = new_depositEOA;
    }


    event Invest(address depositEOA,address to,uint value);

    function invest() public payable returns(bool, uint){
        ICOstate = ICO_state();
        require(ICOstate == State.running,"ico ended/halted");

        require(raisedamount < hardcap,"hardcap reached");
        raisedamount += msg.value;
        require(msg.value >= minBUY && msg.value < maxBUY,"price range mismatch");
        uint tokens = msg.value / tokenprice;

        depositEOA.transfer(msg.value);
        balances[founder] -= tokens;
        balances[msg.sender] += tokens;

        emit Invest(depositEOA,msg.sender,msg.value);
        return (true, tokens);
         
    }

    receive() external payable {
        invest();
    }

    function transfer(address recipient, uint tokens) public override returns (bool){
        ICOstate = ICO_state();
        require(block.timestamp > lockuptime,"you cant spend now,wait till lockup lifted");
        MAX.transfer(recipient,tokens);
        return true;
    }

    function transferFrom(address sender,address recipient,uint tokens) public  override returns (bool){
        ICOstate = ICO_state();
        require(block.timestamp > lockuptime,"you cant spend now,wait till lockup lifted");
        MAX.transferFrom(sender,recipient,tokens);
        return true;   
    }
    
    function burn() public OnlyOwner{
        ICOstate = ICO_state();
        require(ICOstate == State.afterend);

        uint tokenstoburn;
        (,tokenstoburn) = invest();

        balances[founder] -= tokenstoburn; 
    }


}