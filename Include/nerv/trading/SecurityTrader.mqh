#include <nerv/core.mqh>
#include <nerv/core/Object.mqh>
#include <nerv/trading/Security.mqh>

/*
Class: nvSecurityTrader

Base class representing a trader 
*/
class nvSecurityTrader : public nvObject
{
protected:
  nvSecurity _security;

  string _symbol;

  double _traderWeight;

public:
  /*
    Class constructor.
  */
  nvSecurityTrader(string symbol)
    : _security(symbol)
  {
    logDEBUG("Creating Security Trader for "<<symbol)

    _symbol = symbol;
    
    _traderWeight = 1.0;
  }

  /*
    Copy constructor
  */
  nvSecurityTrader(const nvSecurityTrader& rhs) : _security("")
  {
    this = rhs;
  }

  /*
    assignment operator
  */
  void operator=(const nvSecurityTrader& rhs)
  {
    THROW("No copy assignment.")
  }

  /*
    Class destructor.
  */
  ~nvSecurityTrader()
  {
    logDEBUG("Deleting SecurityTrader")
  }

  /*
  Function: update
  
  Method called to update the state of this trader 
  normally once every fixed time delay.
  */
  virtual void update(datetime ctime)
  {

  }
  
  virtual void onTick()
  {

  }
};
