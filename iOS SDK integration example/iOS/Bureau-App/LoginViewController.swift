//
//  ViewController.swift
//  SilentAuthCheck
//
//  Created by Kurian Ninan K on 26/09/20.
//  Copyright © 2020 Keyvalue. All rights reserved.
//

import UIKit
import BureauAuthentication

class LoginViewController: UIViewController {
    
    let activityView = UIActivityIndicatorView(style: .gray)
    
    @IBOutlet weak var textFieldPhoneNumber: UITextField!
    @IBOutlet weak var imagePhoneVerified: UIImageView!
    
    var correlationId = String()
    var count = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func buttonLogin(_ sender: Any) {
        
        //correlation ID
        correlationId = UUID().uuidString
        
        //BureauSilentAuth SDK
        let authSDKObj = BureauAuth.Builder()
            .setClientId(clientId: "a4a57c2d-d4f2-470d-964f-742327025c84")
            .setMode(mode: .production)
            .setTimeout(timeoutinSeconds: 60)
            .build()
        
        guard let phoneNumberValue = self.textFieldPhoneNumber.text else {
            self.showAlert(message: "Enter valid mobile Number")
            return
            
        }
        
        showActivityIndicatory()
        // Call this API in background thread, otherwise it will freeze the UI, since semaphore is used for timeout
        DispatchQueue.global(qos: .userInitiated).async {
            let response = authSDKObj.makeAuthCall(mobile: "91\(phoneNumberValue)", correlationId: self.correlationId)
            print("Response: ",response)
            self.callUserInfoAPI()
        }
    }
    
    //User info API
    func callUserInfoAPI(){
        let queryItems = [URLQueryItem(name: "transactionId", value: self.correlationId)]
        var urlComps = URLComponents(string: "https://api.bureau.id/v2/auth/userinfo")!
        urlComps.queryItems = queryItems
        let finalUrl = urlComps.url!.absoluteString
        var request = URLRequest(url: URL(string: finalUrl)!)
        request.timeoutInterval = 1
        request.httpMethod = "GET"
        request.setValue("$babab5b5-404c-4180-8e49-a24b0c924f3ca5f4d902-c29a-4478-ab19-884dc896ec05$", forHTTPHeaderField: "X-Bureau-Auth-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            if error == nil{
                do {
                    let json = try JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                    if let mobileNumberValue = json["mobileNumber"] as? String{
                        DispatchQueue.main.async {
                            self.stopActivityIndicatory()
                            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                            let newViewController = storyBoard.instantiateViewController(withIdentifier: "success") as! SuccessViewController
                            newViewController.mobileNumber = mobileNumberValue
                            newViewController.modalPresentationStyle = .fullScreen
                            self.present(newViewController, animated: false, completion: nil)
                        }
                    }else{
                        if let codePresent = json["code"] as? Int{
                            //if code == 202100, make the api call again for 10 times
                            if codePresent == 202100{
                                if self.count <= 10{
                                    self.count += 1
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                                        self.callUserInfoAPI()
                                    })
                                }else{
                                    return
                                }
                            }else{
                                DispatchQueue.main.async {
                                    self.stopActivityIndicatory()
                                    if let message = json["message"] as? String{
                                        self.showAlert(message: message)
                                    }
                                }
                                return
                            }
                        }else{
                            DispatchQueue.main.async {
                                self.stopActivityIndicatory()
                                self.showAlert(message: "Error occured, please try again")
                            }
                            return
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.stopActivityIndicatory()
                        self.showAlert(message: "Error occured, please try again")
                    }
                }
            }else{
                DispatchQueue.main.async {
                    self.stopActivityIndicatory()
                    self.showAlert(message: "Error occured, please try again")
                }
            }
        })
        task.resume()
    }
    
    
    func showAlert(message: String){
        let alert = UIAlertController(title:  NSLocalizedString("alert", comment: ""), message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title:  NSLocalizedString("ok", comment: ""), style: UIAlertAction.Style.default, handler: nil))
        alert.popoverPresentationController?.sourceView = self.view
        self.present(alert, animated: true, completion: nil)
    }
    
    func showActivityIndicatory() {
        activityView.center = self.view.center
        self.view.addSubview(activityView)
        activityView.startAnimating()
    }
    
    func stopActivityIndicatory() {
        activityView.stopAnimating()
    }
}

