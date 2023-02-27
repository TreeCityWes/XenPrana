//       ██╗  ██╗███████╗███╗   ██╗    ██████╗ ██████╗  █████╗ ███╗   ██╗ █████╗ 
//       ╚██╗██╔╝██╔════╝████╗  ██║    ██╔══██╗██╔══██╗██╔══██╗████╗  ██║██╔══██╗
//        ╚███╔╝ █████╗  ██╔██╗ ██║    ██████╔╝██████╔╝███████║██╔██╗ ██║███████║
//        ██╔██╗ ██╔══╝  ██║╚██╗██║    ██╔═══╝ ██╔══██╗██╔══██║██║╚██╗██║██╔══██║
//       ██╔╝ ██╗███████╗██║ ╚████║    ██║     ██║  ██║██║  ██║██║ ╚████║██║  ██║
//       ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝   
//                                                                                                                           
//       🅾🅵🅵🅸🅲🅸🅰🅻 🆇🅴🅽 🅲🅰🆂🆃 🅿🆁🅾🅹🅴🅲🆃
//
//      - 5% Entry fee
//      - 5% Exit fee
//      - 5% Will be burned by using the XEN burn function
//      - 10% If you refer other participants under your link
//      - Stable, relax 'n divs
//      - Immutable
//
//      Xen Prana is a dApp that uses the XEN token, that alone is a success concept without any extra ingredients, right?
//      Buy $PRANA with your XEN and receive dividends in XEN.
//      Everyone who participates in the dApp pays a 5% entry fee.
//      This 5% will be distributed among all $PRANA holders in XEN dividends, the same case when someone sells $PRANA.
//      Did you know that 5% of the amount someone uses in XEN to buy $PRANA is burned.
//      Because 5% of the amount someone spends on XEN to buy $PRANA is burned with the burn function of the official XEN contract.
//      Stable, you never lose more than the buy, sell and burn fee. Once ROI, always means profit!
//      The total amount of balance in this contract to XEN, divide that by 100 and multiply by 5, and that's how much this contract has already burned.
//      Or just call our totalXenBurned function and you'll know right away.
//
//      - https://xencast.io/ 
//
//      - SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./TestXen2.sol";

// Xen Prana Contract
contract XenPrana is IBurnRedeemable {

  // $PRANA data
  string public name = "Xen Prana";
  string public symbol = "PRANA";
  uint8 constant public decimals = 18;

  // Owner and admin public data
  address public Owner;
  address public Admin;

  // Settings
  uint256 public buyFee = 5;
  uint256 public sellFee = 5;
  uint256 public burnFee = 5;
  uint256 public referralFee = 10;
  uint256 public refRequirement = 50000 * (10 ** decimals);
  uint256 internal profitPerShare;
  uint256 internal tokenSupply;
  uint256 constant internal magnitude = 2 ** 64;
  
  uint256 public bigRefBuy = 10000 * (10 ** decimals);

  // Public infomatics
  uint256 public pranaHolders;
  uint256 public totalXenBurned;
  uint256 public launchDate;
  uint256 public totalReferrals;
  uint256 public totalReferred;
  uint256 public highestReferral;
  address public highestReferrer;

  // User activity struct
  struct userActivity {
    uint256 buys;
    uint256 sells;
    uint256 reinvested;
    uint256 totalInvested;
    uint256 totalDividends;
    uint256 totalBurned;
    uint256 totalProfit;
    bool hasRoi;
  }

  // User referral stats
  struct userReferrals {
    uint256 referrals;
    uint256 xenEarned;
  }

  // Mappings
  mapping (address => uint256) internal pranaBalanceLedger;
  mapping (address => uint256) internal referralBalance;
  mapping (address => uint256) internal contributed;
  mapping (address => int256) internal payoutsTo;
  mapping (address => bool) internal admin;
  mapping (address => bool) internal pranaHolder;
  mapping (address => userActivity) public activityData;
  mapping (address => userReferrals) public referralData;

  // IERC20 is Xen token
  XENCrypto public xenToken;

  // Xen burner
  address public xenBurner;

  // Deployment constructor setting for name, symbol (i.e prana) and XEN address 
  constructor (address xenAddress, uint256 _launchDate) {
     xenToken = XENCrypto(xenAddress);
     launchDate = _launchDate;
     Owner = address(msg.sender);
     Admin = address(msg.sender);
  }

  // Events
  event onTokenPurchase(
      address indexed buyAddress,
      uint256 incomingXen,
      uint256 tokensMinted,
      address indexed referredBy,
      uint timestamp
    );

  event onTokenSell(
      address indexed sellAddress,
      uint256 tokensBurned,
      uint256 xenEarned,
      uint timestamp
    );

  event onReinvestment(
      address indexed requestAddress,
      uint256 xenReinvested,
      uint256 tokensMinted
    );

  event onWithdraw(
      address indexed requestAddress,
      uint256 xenWithdrawn
    );

  event onDistribute(
      address indexed requestAddress,
      uint256 price
    );

  event Transfer(
      address indexed from,
      address indexed to,
      uint256 tokens
    );

  event Burn(
      address indexed userAddress,
      uint256 amount
    );

  // Check if `xenAmount` match on transfer
  function checkXenTransfer (uint256 xenAmount) private {
     require (xenToken.transferFrom(msg.sender, address(this), xenAmount) == true);
  }

  // Give admin permissions to address
  function setAdmin (address _address) external onlyOwner {
      admin[_address] = true;
  }

  // Revoke admin permissions from address
  function removeAdmin (address _address) external onlyOwner {
      admin[_address] = false;
  }

  // Function to change the amount that will be considered as `bigRefBuy`
  function setBigRefBuy (uint256 _bigRefBuy) external onlyAdmin {
    bigRefBuy = _bigRefBuy;
  }

  // Can also be used to postpone to another date (if not launched yet)
  function setLaunchDate (uint256 _launchDate) external onlyAdmin {
    require (_launchDate > block.timestamp + 3600, "Must be at least 1 hour apart from this moment");
    launchDate = _launchDate;
  }

  // Required by XEN
  function onTokenBurned(address user, uint256 amount) external {
    require(msg.sender == address(xenToken), "Callback not from XEN");
    emit Burn(user, amount);
  }

  // Possibility to change refRequirement (i.e amount prana needed to activate link)
  function setRefRequirement (uint256 _refRequirement) external onlyAdmin {
    require (_refRequirement > 0, "Cannot be zero");
    refRequirement = _refRequirement;
  }

  // Possibility to change referral share percentage
  function setRefPercentage (uint256 _referralFee) external onlyAdmin {
      require (_referralFee > 0, "Cannot be zero");
      require (_referralFee < 31, "Cannot be more then thirty");
      referralFee = _referralFee;
  }

  // Check if msg.sender is a contract
  function isContract(address _address) internal view returns (bool) {
      uint256 size;
      assembly { size := extcodesize(_address) }
      return size > 0;
  }

  // Xen balance of this contract
  function totalXenBalance() public view returns (uint256) {
    return xenToken.balanceOf(address(this));
  }

  // Prana total supply
  function totalSupply() public view returns (uint256) {
    return tokenSupply;
  }

  // Requester tokens
  function myPrana() public view returns (uint256) {
    address requestAddress = msg.sender;
    return balanceOf(requestAddress);
  }

  // Prana balance of address
  function balanceOf(address Address) public view returns (uint256) {
    return pranaBalanceLedger[Address];
  }

  // Check requester dividends
  function myDivs(bool includeReferralShare) public view returns (uint256) {
    address requestAddress = msg.sender;
    return includeReferralShare ? 
    divsOf(requestAddress) + referralBalance[requestAddress] 
    :
    divsOf(requestAddress);
  }

  // Dividends of address
  function divsOf(address Address) public view returns (uint256) {
    return (uint256) ((int256) (profitPerShare * pranaBalanceLedger[Address])
    - payoutsTo[Address]) / magnitude;
  }

  // Return prana price in xen
  function buyPrice() public view returns (uint256) {
    uint256 xen = 1e18;
    uint256 dividends = xen / 100 * buyFee;
    uint256 burnTax = xen / 100 * burnFee;
    uint256 taxedXen = dividends + burnTax;
    uint256 totalTaxedXen = xen - taxedXen;
    return totalTaxedXen;
  }

  // Return sell price in xen
  function sellPrice() public view returns (uint256) {
    uint256 xen = 1e18;
    uint256 dividends = xen / 100 * sellFee;
    uint256 taxedXen = xen - dividends;
    return taxedXen;
  }

  // Function to check how much an address burned through this contract
  function userBurned (address userAddress) public view returns (uint256) {
    return activityData[userAddress].totalBurned;
  }

  // Function to check how much requester burned through this contract
  function myBurns() public view returns (uint256) {
    address requesterAddress = msg.sender;
    return activityData[requesterAddress].totalBurned;
  }

  // Function to check how much requester burned through this contract
  function checkRoi (address userAddress) public view returns (bool) {
    return activityData[userAddress].hasRoi;
  }

  // Xen to prana calculation
  function calcPranaReceived (uint256 xenToSpend) public view returns (uint256) {
    uint256 dividends = xenToSpend / 100 * buyFee;
    uint256 burnAmount = xenToSpend / 100 * burnFee;
    uint256 totalTaxed = dividends + burnAmount;
    uint256 correctedPrana = xenToSpend - totalTaxed;
    return correctedPrana;
  }

  // Prana to xen calculation
  function calcXenReceived (uint256 pranaToSell) public view returns (uint256) {
    require(pranaToSell <= tokenSupply);
    uint256 dividends = pranaToSell / 100 * sellFee;
    uint256 xenAmount = pranaToSell - dividends;
    return xenAmount;
  }

  // Modifiers
  modifier onlyOwner() {
    require(msg.sender == Owner);
    _;
  }

  modifier onlyAdmin() {
    require(msg.sender == Admin);
    _;
  }

  modifier notContract() {
      require(!isContract(msg.sender), "Contract not allowed");
      require(msg.sender == tx.origin, "Proxy contract not allowed");
      _;
  }

  modifier onlyTokenHolders {
      require(myPrana() > 0);
      _;
  }

  modifier onlyDivs {
      require(myDivs(true) > 0);
      _;
  }

  function buyPrana (uint256 xenAmount, address referredBy) public returns (uint256) {
    checkXenTransfer(xenAmount);
    uint256 minimumXen;
    // In order to activate the buy function, we need to buy with 0.000000000000000001 XEN first
    if (Admin == msg.sender) {

      // XEN does not allow burnings below 1e18, just to clarify why we dont burn at the activation transaction
      minimumXen = 0;

      return processXen(referredBy, msg.sender, xenAmount);
    } else {
      // When buy function activated, we can resume the normal way
      uint256 burnAmount = xenAmount / 100 * burnFee;

      // Minimum of 100 XEN so that we are always in the safe zone of the minimum burn number required by the XEN contract
      minimumXen = 100e18;
      require (xenAmount >= minimumXen, "Minimum is 100 XEN");

      // Calc total number of XEN needed
      uint256 totalXen = xenAmount + burnAmount;

      // Revert if balance not meets the total needed number
      require (xenToken.balanceOf(msg.sender) >= totalXen, "Amount exceeds request");

      // Update user stats
      activityData[msg.sender].totalBurned = 
      activityData[msg.sender].totalBurned + burnAmount;

      // Initiate the transaction: burn the XEN and buy the PRANA
      xenToken.stake()
      IBurnableToken(xenToken).burn(msg.sender, burnAmount);

      return processXen(referredBy, msg.sender, xenAmount);
    }
  }

  function sellPrana (uint256 amountOfPrana) onlyTokenHolders public {
    address sellAddress = msg.sender;
    require (amountOfPrana <= pranaBalanceLedger[sellAddress]);

    uint256 dividends = amountOfPrana / 100 * sellFee;
    uint256 taxedXen = amountOfPrana - dividends;

    // Update sell amount in activityData struct
    activityData[sellAddress].sells += 1;

    tokenSupply = tokenSupply - amountOfPrana;
    pranaBalanceLedger[sellAddress] = pranaBalanceLedger[sellAddress] - amountOfPrana;

    int256 updatedPayouts = (int256)
    (profitPerShare * amountOfPrana +
    (taxedXen * magnitude));
    payoutsTo[sellAddress] -= updatedPayouts;

    if (tokenSupply > 0 ) {
      profitPerShare = profitPerShare + 
      (dividends * magnitude) / tokenSupply;
    }

    if (pranaBalanceLedger[sellAddress] < 0) {
        // Update pranaHolder boolean
        pranaHolder[sellAddress] = false;
        // Sub `sellAddress` from pranaHolders
        pranaHolders = pranaHolders - 1;
    }

    emit Transfer(sellAddress, address(0), amountOfPrana);
    emit onTokenSell(sellAddress, amountOfPrana, taxedXen, block.timestamp);
  }

  function withdrawDivs() onlyDivs public {
    address requestAddress = msg.sender;
    uint256 dividends = myDivs(false);

    payoutsTo[requestAddress] += (int256) (dividends * magnitude);
    dividends += referralBalance[requestAddress];
    referralBalance[requestAddress] = 0;

    // Update activity data of `requestAddress` in the structure 
    activityData[requestAddress].totalDividends =
    activityData[requestAddress].totalDividends + dividends;

    // Check if `requestAddress` is at ROI, if true, add dividends to current profit
    if (activityData[requestAddress].hasRoi == true) {
      activityData[requestAddress].totalProfit = 
      activityData[requestAddress].totalProfit + dividends;     
    }   

    xenToken.transfer(requestAddress, dividends);
    emit onWithdraw(requestAddress, dividends);
  }

  function reinvest() onlyDivs public {
    address requestAddress = msg.sender;
    uint256 dividends = myDivs(false);

    // Update activity data of `requestAddress` in the structure
    activityData[requestAddress].reinvested += 1;
    activityData[requestAddress].buys += 1;
    activityData[requestAddress].totalDividends =
    activityData[requestAddress].totalDividends + dividends;
    activityData[requestAddress].totalInvested = 
    activityData[requestAddress].totalInvested + dividends;

    // Check if `requestAddress` is at ROI, if true, add dividends to current profit
    if (activityData[requestAddress].hasRoi == true) {
      activityData[requestAddress].totalProfit = 
      activityData[requestAddress].totalProfit + dividends;     
    }   

    payoutsTo[requestAddress] += (int256) (dividends * magnitude);
    dividends += referralBalance[requestAddress];
    referralBalance[requestAddress] = 0;

    uint256 prana = processXen(address(0), requestAddress, dividends);
    emit onReinvestment(requestAddress, dividends, prana);
  }

  function exitDapp() external {
    address requestAddress = msg.sender;
    uint256 prana = pranaBalanceLedger[requestAddress];
    if (prana > 0) {
      sellPrana(prana);
      withdrawDivs();
    }
    pranaHolder[requestAddress] = false;
    pranaHolders = pranaHolders - 1;
  }

  function processXen (address referredBy, address buyAddress, uint256 incomingXen) notContract internal returns (uint256) {
    if (pranaHolder[buyAddress] == false) {
      pranaHolders = pranaHolders + 1;
      pranaHolder[buyAddress] = true;
    }

    activityData[buyAddress].buys += 1;
    activityData[buyAddress].totalInvested = 
    activityData[buyAddress].totalInvested + incomingXen;

    // Check wether `buyAddress` is at ROI and update boolean
    if (activityData[buyAddress].totalDividends >
        activityData[buyAddress].totalInvested) {
        activityData[buyAddress].hasRoi = true;
    } else {
        activityData[buyAddress].hasRoi = false;
    }

    // Add `burnFee` in the calculations
    uint256 burnAmount = incomingXen / 100 * burnFee;
    uint256 undividedDivs = incomingXen / 100 * buyFee;
    uint256 referralShare = undividedDivs / 100 * referralFee;
    uint256 dividends = undividedDivs - referralShare;
    uint256 amountOfPrana = calcPranaReceived(incomingXen);
    uint256 calcFee = dividends * magnitude;

    require (amountOfPrana > 0 &&
    amountOfPrana + tokenSupply > tokenSupply);

    if (referredBy != address(0) &&
    referredBy != buyAddress &&
    pranaBalanceLedger[referredBy] >= refRequirement) {
    // Update `referralBalance` and `userReferrals` struct
    referralBalance[referredBy] = referralBalance[referredBy] + referralShare;
    referralData[referredBy].referrals = referralData[referredBy].referrals + 1;
    referralData[referredBy].xenEarned = referralData[referredBy].xenEarned + referralShare;

    // Update values of `totalReferrals` and `totalReferred`
    totalReferrals = totalReferrals + 1;
    totalReferred = totalReferred + incomingXen;
      
    // Check if referred amount is higher then current `highestReferral`
    if (incomingXen > highestReferral) {
         highestReferral = incomingXen;
         highestReferrer = referredBy;
      }
    } 

      dividends = dividends + referralShare;
      calcFee = dividends * magnitude;

    if (tokenSupply > 0) {
      tokenSupply = tokenSupply + amountOfPrana;
      profitPerShare += (dividends * magnitude / tokenSupply);
      calcFee = calcFee - (calcFee - (amountOfPrana * (dividends * magnitude / tokenSupply)));
    } else {
      tokenSupply = amountOfPrana;
    }
 
      // Update the pranaBalanceLedger
      pranaBalanceLedger[buyAddress] = pranaBalanceLedger[buyAddress] + amountOfPrana;
      int256 updatedPayouts = (int256) (profitPerShare * amountOfPrana - calcFee);
      payoutsTo[buyAddress] += updatedPayouts;

      // Update total amount burned through this contract
      totalXenBurned = totalXenBurned + burnAmount;

      emit Transfer(address(0), msg.sender, amountOfPrana);
      emit onTokenPurchase(buyAddress, incomingXen, amountOfPrana, referredBy, block.timestamp);

      return amountOfPrana;
  }

  // Confirms support for IBurnRedeemable interfaces
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
      return interfaceId == type(IBurnRedeemable).interfaceId;
  }
}