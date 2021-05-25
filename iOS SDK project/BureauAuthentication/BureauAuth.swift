/*******************************************************************************************
 * Owner  : Kurian Ninan K
 * File Name        :  BureauAuth.swift
 * Module Name      :  Common
 * Description      : This class calls the initiate and finalise URL
 *******************************************************************************************/

import Foundation

enum NetworkError: Error {
    case url
    case server
}

public class BureauAuth {
    private let components: URLComponents
    private let clientId : String?
    private let mode : Mode?
    private let callBackUrl : String?
    private let timeOut: Int?
    
    private init(components: URLComponents,clientId: String?,mode:  Mode?,callBackUrl: String?,timeOut: Int?) {
        self.components = components
        self.clientId = clientId
        if let modeValue = mode{
            self.mode = modeValue
        }else{
            self.mode = Mode.production
        }
        self.callBackUrl = callBackUrl
        self.timeOut = timeOut
    }
    
    public enum Mode {
        case sandbox
        case production
    }
    
    public class Builder{
        private var components: URLComponents
        private var clientId : String?
        private var mode = Mode.production
        private var callBackUrl : String?
        private var timeOut: Int?
        
        public init() {
            self.components = URLComponents()
            self.clientId = ""
            self.mode = Mode.production
            self.callBackUrl = String()
            self.timeOut = 10
        }
        
        public func setClientId(clientId: String) -> Builder {
            self.clientId = clientId
            return self
        }
        
        public func setCallBackUrl(callBackUrl: String) -> Builder {
            self.callBackUrl = callBackUrl
            return self
        }
        
        public func setTimeout(timeoutinSeconds: Int) -> Builder{
            self.timeOut = timeoutinSeconds
            return self
        }
        
        public func setMode(mode: Mode) -> Builder{
            self.mode = mode
            return self
        }
        
        public func build() -> BureauAuth {
            if self.mode == .production{
                self.components.host = "https://api.bureau.id/v2/auth/"
            }else{
                self.components.host = "https://api.sandbox.bureau.id/v2/auth/"
            }
            return BureauAuth(components: self.components, clientId: self.clientId, mode: self.mode, callBackUrl: self.callBackUrl, timeOut: self.timeOut)
        }
    }
    
    typealias FireAPICompletion =  (_ respose :String?, _ error: NetworkError?) -> Void
    // API exposed to the SDK

    public func makeAuthCall(mobile: String,correlationId: String) -> String{
          var response = ""
          let semaphore = DispatchSemaphore(value: 0)
          if mode==Mode.sandbox{
            print("Bureau SDK:","Bureau SDK Transaction Mobile: ",mobile," CorrelationID: ",correlationId," clientID: ",clientId ?? "DEFCLIENTID"," timeout: ",timeOut ?? -1);
          }
          DispatchQueue.global(qos: .background).async {
              //Initiate URL - fireURL API with finalise Bool as False
              self.fireURL(mobileNumber: mobile, correlationId: correlationId) { (apiResponse, networkError) in
                    if let responseValue = apiResponse {
                       response = responseValue
                    } else {
                      response = "Error"
                    }
                  semaphore.signal()
              }
          }
          let timeoutInSeconds = timeOut ?? 10
          if semaphore.wait(timeout: .now() + .seconds(timeoutInSeconds)) == .timedOut {
            if mode==Mode.sandbox{
              print("Bureau SDK:","Timeout Exiting")
            }
            response = "timeout"
          }
          return response
      }
    
    private func fireURL(mobileNumber: String,correlationId: String,completionHandler: @escaping FireAPICompletion){
        if mode==Mode.sandbox{
        print("Bureau SDK:","fireURL: correlationID : ", correlationId);
        }
        var response = "ERROR: Unknown HTTP Response"
        let queryItems = [URLQueryItem(name: "clientId", value: clientId), URLQueryItem(name: "correlationId", value: correlationId),URLQueryItem(name: "msisdn", value: mobileNumber),URLQueryItem(name: "callbackUrl", value: callBackUrl)]
        var urlComps = URLComponents(string: "\(components.host ?? "https://api.bureau.id/v2/auth/")initiate")!
        urlComps.queryItems = queryItems
        let finalUrl = urlComps.url!.absoluteString
        response = HTTPRequester.performGetRequest(URL(string: finalUrl))
        if mode==Mode.sandbox{
        print("Bureau SDK:","FireURL Get Request Completed. Response: ",response)
        }
        if response.range(of:"REDIRECT:") != nil {
        // Get redirect link
        let redirectRange = response.index(response.startIndex, offsetBy: 9)...
        let redirectLink = String(response[redirectRange])
        
        // Make recursive call
            response = fireRedirectURL(url: redirectLink)
        } else if response.range(of:"ERROR: Done") != nil {
            completionHandler(nil, NetworkError.server)
        }
        completionHandler(response, nil)
    }
    
    private func fireRedirectURL(url:String) -> String {
        if mode==Mode.sandbox{
            print("Bureau SDK:","Bureau SDK Logs - fireURLRedirect: ", url);
        }
        var response = "ERROR: Unknown HTTP Response"
        if let urlValue = URL(string: url){
            response = HTTPRequester.performGetRequest(urlValue)
        }
        if mode==Mode.sandbox{
            print("Bureau SDK:","FireURLRedirect Get Request Completed. Response: ",response)
        }
        if response.range(of:"REDIRECT:") != nil {
            // Get redirect link
            let redirectRange = response.index(response.startIndex, offsetBy: 9)...
            let redirectLink = String(response[redirectRange])
            // Make recursive call
            response = fireRedirectURL(url: redirectLink)
        } else if response.range(of:"ERROR: Done") != nil {
            return "ERROR: Unknown HTTP Response"
        }
        return response
    }
}
