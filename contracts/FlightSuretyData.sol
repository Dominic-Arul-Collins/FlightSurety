pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct Airlines {
        bool isRegistered;
        bool isOperational;
    }

    struct Voters {
        bool status;
    }

    struct Insurance {
        address passenger;
        uint256 amount;
    
    }

    struct Fund {
        uint256 amount;
    }

    mapping(address => uint256) private authorizedCaller;
    mapping(address => Airlines) airlines;                             
    mapping(address => Insurance) insurance;                           
    mapping(address => uint256) balances;
    mapping(address => Fund) funds;
    address[] multiCalls = new address[](0);
    mapping(address => uint) private voteCount;
    mapping(address => Voters) voters;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event FundedAirLines(address funded, uint256 value);
    event Withdraw(address sender,uint256 amount);
    event PurchaseInsurance(address airline, address sender, uint256 amount);
    event AuthorizedContract(address authContract);
    event DeAuthorizedContract(address authContract);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    // ------------------- Multi-party Helpers -------------------------

    function setmultiCalls(address account) private {
        multiCalls.push(account);
    }
    function multiCallsLength() external requireIsOperational returns(uint){
        return multiCalls.length;
    }


    //----------------- Airline Operational Helpers------------------------------
    function getAirlineOperatingStatus(address account)  requireIsOperational returns(bool){
        return airlines[account].isOperational;
    }

    function setAirlineOperatingStatus(address account, bool status)  requireIsOperational {
        airlines[account].isOperational = status;
    }

    //----------------- Airline Registration Voters Helpers------------------------------

    function getVoteCounter(address account)  requireIsOperational returns(uint){
        return voteCount[account];
    }
    function resetVoteCounter(address account)  requireIsOperational{
        delete voteCount[account];
    }
    function getVoterStatus(address voter)  requireIsOperational returns(bool){
        return voters[voter].status;
    }
    function addVoters(address voter) {
        voters[voter] = Voters({
            status: true
        });
    }
    function addVoterCounter(address airline, uint count) {
        uint vote = voteCount[airline];
        voteCount[airline] = vote.add(count); 
    }

    function getAirlineRegistrationStatus(address account)  requireIsOperational returns(bool){
        return airlines[account].isRegistered;
    }

    // ---------------------------- Insurance Helper  --------------------------
    function registerInsurance(address airline, address passenger, uint256 amount)  requireIsOperational{
        insurance[airline] = Insurance({
            passenger: passenger,
            amount: amount
        });
        uint256 getFund = funds[airline].amount;
        funds[airline].amount = getFund.add(amount);
    }

    //-----------------------------Fund Helper -------------------------
    function fundAirline(address airline, uint256 amount) {
        funds[airline] = Fund({
            amount: amount
        });

    }
    function getAirlineFunding(address airline)  returns(uint256){
        return funds[airline].amount;
    }


    function authorizeCaller
                            (
                                address contractAddress
                            )
                            
                            requireContractOwner
    {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract
                            (
                                address contractAddress
                            )
                            
                            requireContractOwner
    {
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function _registerAirline
                            (   
                                address account,
                                bool isOperational
                            )
                            external
                            requireIsOperational
    {
        airlines[account] = Airlines({
            isRegistered: true,
            isOperational: isOperational
        });
        setmultiCalls(account);
    }

    /**
    * @dev Check if an airline is registered
    *
    * @return A bool that indicates if the airline is registered
    */   
    function isAirline
                            (
                                address account
                            )
                            external
                            
                            returns(bool)
    {
        require(account != address(0), "Address account can't be Zero address");

        return airlines[account].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                (
                    address airline
                    
                )
                external
                payable
                requireIsOperational
    {
        // Check if airline is operational
        require(getAirlineOperatingStatus(airline),"Airline is NOT operational");
        
        // Check if amount is between 0 and 1 ether
        require((msg.value > 0 ether) && (msg.value <= 1 ether), "Insurance amount should be between 0 and 1 ether");

        // Track insurance details
        registerInsurance(airline, msg.sender, msg.value);

        emit PurchaseInsurance(airline, msg.sender, msg.value);

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                            (
                                address airline,
                                address passenger,
                                uint256 amount
                            )
                            external
                            requireIsOperational
                              
    {
        // Calculating the amount to be credited to the insuree (1.5x)
        uint256 requiredAmount = insurance[airline].amount.mul(3).div(2);

        require(insurance[airline].passenger == passenger, "Passenger did not purchase insurance");
        require(requiredAmount == amount, "Amount mismatches");
        require((passenger != address(0)) && (airline != address(0)), "Address account can't be Zero address");

        balances[passenger] = amount;

    }

    /**
        @dev Withdraw balance from an account
     */

    function withdraw
                        (
                            address passenger
                        )                      
                        requireIsOperational
                        returns(uint256)
    {
        uint256 withdrawAmount = balances[passenger];

        delete balances[passenger];
        return withdrawAmount;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            requireIsOperational
                            
    {
        require(getPassengerCredit(msg.sender) > 0, "Balance is zero");

        uint256 withdrawValue = withdraw(msg.sender);
        
        // Transfer ethers to passenger's wallet
        msg.sender.transfer(withdrawValue);
        
        emit Withdraw(msg.sender, withdrawValue);


    }

    function getInsuredPassenger_amount(address airline)  requireIsOperational  returns(address, uint256){
        return (insurance[airline].passenger, insurance[airline].amount);
    }

    function getPassengerCredit(address passenger)  requireIsOperational returns(uint256){
        return balances[passenger];
    }  


   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                (
                )
                public
                payable
                requireIsOperational
    {
        // Verify the fund is 10 ether
        require(msg.value == 10 ether,"Funds should be 10 ether");

        // Verify airline not yet funded
        require(!getAirlineOperatingStatus(msg.sender), "Airline is already funded");

        fundAirline(msg.sender, msg.value);

        setAirlineOperatingStatus(msg.sender, true);

        emit FundedAirLines(msg.sender, msg.value);
        
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

