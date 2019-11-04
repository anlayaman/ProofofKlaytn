
pragma solidity 0.4.24;
 
/*
*
* 24% Buy Fees
* 24% Sell Fees
* 1% Transfer Fees
* 1.5% Dev Fees on Buy and Sell
*/


contract Ownable {
    
    address public owner;

    constructor() public {
        owner = msg.sender;
    }
    

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

}


contract ProofofKlaytn is Ownable{
    using SafeMath for uint256;
    
     modifier onlyBagholders {
        require(myTokens() > 0);
        _;
    }
      
     modifier onlyStronghands {
        require(myDividends(true) > 0);
        _;
    }
    
   
      
    event onTokenPurchase(
        address indexed customerAddress,
        uint256 incomingklaytn,
        uint256 tokensMinted,
        address indexed referredBy,
        uint timestamp,
        uint256 price
);

    event onTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 klaytnEarned,
        uint timestamp,
        uint256 price
);

    event onReinvestment(
        address indexed customerAddress,
        uint256 klaytnReinvested,
        uint256 tokensMinted
);

    event onWithdraw(
        address indexed customerAddress,
        uint256 klaytnWithdrawn
);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
);

    string public name = "Proof of Klaytn";
    string public symbol = "PoK";
    uint8 constant public decimals = 18;
    uint8 constant internal transferFee_ = 1;
    uint8 constant internal ExitFee_ = 24; 
    uint8 constant internal refferalFee_ = 8;
    uint8 constant internal DevFee_ = 15; 
    uint8 constant internal IntFee_ = 35; 
    uint256 constant internal tokenPriceInitial_ = 0.0000001 ether;
    uint256 constant internal tokenPriceIncremental_ = 0.00000001 ether;
    uint256 constant internal magnitude = 2**64;
    uint256 public stakingRequirement = 50e18;
  
    
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;
    address dev = 0xf7b4b395852f84468a49f0fc863fa74857c6d929;
    

        function buy(address _referredBy) public payable returns (uint256) {
        uint256 DevFee1 = msg.value.div(100).mul(DevFee_);
        uint256 DevFeeFinal = SafeMath.div(DevFee1, 10);
        dev.transfer(DevFeeFinal);
        purchaseTokens(msg.value, _referredBy);
    }
    
        function() payable public {
        uint256 DevFee1 = msg.value.div(100).mul(DevFee_);
        uint256 DevFeeFinal = SafeMath.div(DevFee1, 10);
        dev.transfer(DevFeeFinal);
        purchaseTokens(msg.value, 0x0);
    }
    
    
    function DivsAddon() public payable returns (uint256) {
        DividendsDistribution(msg.value, 0x0);
    }
    
    

        function reinvest() onlyStronghands public {
        uint256 _dividends = myDividends(false);
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        uint256 _tokens = purchaseTokens(_dividends, 0x0);
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    function exit() public {
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if (_tokens > 0) sell(_tokens);
        withdraw();
    }

    function withdraw() onlyStronghands public {
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false);
        payoutsTo_[_customerAddress] += (int256) (_dividends * magnitude);
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        _customerAddress.transfer(_dividends);
        emit onWithdraw(_customerAddress, _dividends);
    }

    function sell(uint256 _amountOfTokens) onlyBagholders public {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _klaytn = tokensToklaytn_(_tokens);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_klaytn, exitFee()), 100);
        uint256 _devexit = SafeMath.div(SafeMath.mul(_klaytn, 5), 100);
        uint256 _taxedklaytn1 = SafeMath.sub(_klaytn, _dividends);
        uint256 _taxedklaytn = SafeMath.sub(_taxedklaytn1, _devexit);
        uint256 _devexitindividual = SafeMath.div(SafeMath.mul(_klaytn, DevFee_), 100);
        uint256 _devexitindividual_final = SafeMath.div(_devexitindividual, 10);
        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _tokens);
        dev.transfer(_devexitindividual_final); 
        
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedklaytn * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        if (tokenSupply_ > 0) {
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }
        emit onTokenSell(_customerAddress, _tokens, _taxedklaytn, now, buyPrice());
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders public returns (bool) {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        if (myDividends(true) > 0) {
            withdraw();
        }

        uint256 _tokenFee = SafeMath.div(SafeMath.mul(_amountOfTokens, transferFee_), 100);
        uint256 _taxedTokens = SafeMath.sub(_amountOfTokens, _tokenFee);
        uint256 _dividends = tokensToklaytn_(_tokenFee);

        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokenFee);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _taxedTokens);
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        return true;
    }


    function totalklaytnBalance() public view returns (uint256) {
        return this.balance;
    }

    function totalSupply() public view returns (uint256) {
        return tokenSupply_;
    }

    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    function myDividends(bool _includeReferralBonus) public view returns (uint256) {
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + referralBalance_[_customerAddress] : dividendsOf(_customerAddress) ;
    }

    function balanceOf(address _customerAddress) public view returns (uint256) {
        return tokenBalanceLedger_[_customerAddress];
    }

    function dividendsOf(address _customerAddress) public view returns (uint256) {
        return (uint256) ((int256) (profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }

    function sellPrice() public view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _klaytn = tokensToklaytn_(1e18);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_klaytn, exitFee()), 100);
            uint256 _devexit = SafeMath.div(SafeMath.mul(_klaytn, 5), 100);
            uint256 _taxedklaytn1 = SafeMath.sub(_klaytn, _dividends);
            uint256 _taxedklaytn = SafeMath.sub(_taxedklaytn1, _devexit);
            return _taxedklaytn;
        }
    }

    function buyPrice() public view returns (uint256) {
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _klaytn = tokensToklaytn_(1e18);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_klaytn, entryFee_), 100);
            uint256 _devexit = SafeMath.div(SafeMath.mul(_klaytn, 5), 100);
            uint256 _taxedklaytn1 = SafeMath.add(_klaytn, _dividends);
            uint256 _taxedklaytn = SafeMath.add(_taxedklaytn1, _devexit);
            return _taxedklaytn;
        }
    }

    function calculateTokensReceived(uint256 _klaytnToSpend) public view returns (uint256) {
        uint256 _dividends = SafeMath.div(SafeMath.mul(_klaytnToSpend, entryFee_), 100);
        uint256 _devbuyfees = SafeMath.div(SafeMath.mul(_klaytnToSpend, 5), 100);
        uint256 _taxedklaytn1 = SafeMath.sub(_klaytnToSpend, _dividends);
        uint256 _taxedklaytn = SafeMath.sub(_taxedklaytn1, _devbuyfees);
        uint256 _amountOfTokens = klaytnToTokens_(_taxedklaytn);
        return _amountOfTokens;
    }

    function calculateklaytnReceived(uint256 _tokensToSell) public view returns (uint256) {
        require(_tokensToSell <= tokenSupply_);
        uint256 _klaytn = tokensToklaytn_(_tokensToSell);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_klaytn, exitFee()), 100);
        uint256 _devexit = SafeMath.div(SafeMath.mul(_klaytn, 5), 100);
        uint256 _taxedklaytn1 = SafeMath.sub(_klaytn, _dividends);
        uint256 _taxedklaytn = SafeMath.sub(_taxedklaytn1, _devexit);
        return _taxedklaytn;
    }

   function exitFee() public view returns (uint8) {
        return ExitFee_;
    }
    


  function purchaseTokens(uint256 _incomingklaytn, address _referredBy) internal returns (uint256) {
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingklaytn, entryFee_), 100);
        uint256 _referralBonus = SafeMath.div(SafeMath.mul(_undividedDividends, refferalFee_), 100);
        uint256 _devbuyfees = SafeMath.div(SafeMath.mul(_incomingklaytn, 5), 100);
        uint256 _dividends1 = SafeMath.sub(_undividedDividends, _referralBonus);
        uint256 _dividends = SafeMath.sub(_dividends1, _devbuyfees);
        uint256 _taxedklaytn = SafeMath.sub(_incomingklaytn, _undividedDividends);
        uint256 _amountOfTokens = klaytnToTokens_(_taxedklaytn);
        uint256 _fee = _dividends * magnitude;

        require(_amountOfTokens > 0 && SafeMath.add(_amountOfTokens, tokenSupply_) > tokenSupply_);

        if (
            _referredBy != 0x0000000000000000000000000000000000000000 &&
            _referredBy != _customerAddress &&
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            referralBalance_[_referredBy] = SafeMath.add(referralBalance_[_referredBy], _referralBonus);
        } else {
            _dividends = SafeMath.add(_dividends, _referralBonus);
            _fee = _dividends * magnitude;
        }

        if (tokenSupply_ > 0) {
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
            profitPerShare_ += (_dividends * magnitude / tokenSupply_);
            _fee = _fee - (_fee - (_amountOfTokens * (_dividends * magnitude / tokenSupply_)));
        } else {
            tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;
        emit onTokenPurchase(_customerAddress, _incomingklaytn, _amountOfTokens, _referredBy, now, buyPrice());

        return _amountOfTokens;
    }


       function DividendsDistribution(uint256 _incomingklaytn, address _referredBy) internal returns (uint256) {
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingklaytn, 100), 100);
        uint256 _referralBonus = SafeMath.div(SafeMath.mul(_undividedDividends, refferalFee_), 100);
        uint256 _dividends = SafeMath.sub(_undividedDividends, _referralBonus);
        uint256 _taxedklaytn = SafeMath.sub(_incomingklaytn, _undividedDividends);
        uint256 _amountOfTokens = klaytnToTokens_(_taxedklaytn);
        uint256 _fee = _dividends * magnitude;

        require(_amountOfTokens >= 0 && SafeMath.add(_amountOfTokens, tokenSupply_) >= tokenSupply_);

        if (
            _referredBy != 0x0000000000000000000000000000000000000000 &&
            _referredBy != _customerAddress &&
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            referralBalance_[_referredBy] = SafeMath.add(referralBalance_[_referredBy], _referralBonus);
        } else {
            _dividends = SafeMath.add(_dividends, _referralBonus);
            _fee = _dividends * magnitude;
        }

        if (tokenSupply_ > 0) {
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
            profitPerShare_ += (_dividends * magnitude / tokenSupply_);
            _fee = _fee - (_fee - (_amountOfTokens * (_dividends * magnitude / tokenSupply_)));
        } else {
            tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;
        emit onTokenPurchase(_customerAddress, _incomingklaytn, _amountOfTokens, _referredBy, now, buyPrice());

        return _amountOfTokens;
    }

    function klaytnToTokens_(uint256 _klaytn) internal view returns (uint256) {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived =
            (
                (
                    SafeMath.sub(
                        (sqrt
                            (
                                (_tokenPriceInitial ** 2)
                                +
                                (2 * (tokenPriceIncremental_ * 1e18) * (_klaytn * 1e18))
                                +
                                ((tokenPriceIncremental_ ** 2) * (tokenSupply_ ** 2))
                                +
                                (2 * tokenPriceIncremental_ * _tokenPriceInitial*tokenSupply_)
                            )
                        ), _tokenPriceInitial
                    )
                ) / (tokenPriceIncremental_)
            ) - (tokenSupply_);

        return _tokensReceived;
    }

    function tokensToklaytn_(uint256 _tokens) internal view returns (uint256) {
        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _klayReceived =
            (
                SafeMath.sub(
                    (
                        (
                            (
                                tokenPriceInitial_ + (tokenPriceIncremental_ * (_tokenSupply / 1e18))
                            ) - tokenPriceIncremental_
                        ) * (tokens_ - 1e18)
                    ), (tokenPriceIncremental_ * ((tokens_ ** 2 - tokens_) / 1e18)) / 2
                )
                / 1e18);

        return _klayReceived;
    }

 

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}