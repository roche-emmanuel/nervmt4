
// To be defined if we are building a release version.
//#define RELEASE_BUILD
#define USE_OPTIMIZATIONS

#define IS_DYN_POINTER(obj) (CheckPointer(GetPointer(obj))==POINTER_DYNAMIC)
#define IS_AUTO_POINTER(obj) (CheckPointer(GetPointer(obj))==POINTER_AUTOMATIC)
#define IS_VALID_POINTER(obj) (CheckPointer(GetPointer(obj))!=POINTER_INVALID)

#define RELEASE_PTR(ptr)  if (ptr != NULL && IS_DYN_POINTER(ptr)) { delete ptr; ptr = NULL; }
#define THIS GetPointer(this)

#define __WITH_POINTER_EXCEPTION__

#ifdef __WITH_POINTER_EXCEPTION__
#define THROW(msg) { nvStringStream __ss__; \
    __ss__ << msg; \
    nvExceptionCatcher* ec = nvExceptionCatcher::instance(); \
    ec.setLastError(__ss__.str()); \
    if (!ec.isEnabled()) { \
      CObject* obj = NULL; \
      obj.Next(); \            
    } \
  }
#else
#define THROW(msg) { nvStringStream __ss__; \
    __ss__ << msg; \
    nvExceptionCatcher* ec = nvExceptionCatcher::instance(); \
    ec.setLastError(__ss__.str()); \
    if (!ec.isEnabled()) { \      
      ExpertRemove(); \
      return; \
    } \
  }
#endif

#define CHECK(val,msg) if(!(val)) { THROW(__FILE__ << "(" << __LINE__ <<"): " << msg); return; }
#define CHECK_RET(val,ret,msg) if(!(val)) { THROW(__FILE__ << "(" << __LINE__ <<"): " << msg); return ret;}
#define CHECK_PTR(ptr, msg) CHECK(IS_VALID_POINTER(ptr),msg)
#define NO_IMPL(arg) THROW(__FILE__ << "(" << __LINE__ <<"): This method is not implemented.");

#include <Object.mqh>
#include <Arrays/List.mqh>

#include <nerv/core/Object.mqh>
#include <nerv/core/StringStream.mqh>
// #include <nerv/core/Log.mqh>
// #include <nerv/core/ObjectMap.mqh>
// #include <nerv/core/ExceptionCatcher.mqh>

#import "shell32.dll"
int ShellExecuteW(int hwnd,string Operation,string File,string Parameters,string Directory,int ShowCmd);
#import
