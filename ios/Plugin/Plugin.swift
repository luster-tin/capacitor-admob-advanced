import Foundation
import Capacitor
import GoogleMobileAds
import PersonalizedAdConsent

@objc(AdMobAdvanced)
public class AdMobAdvanced: CAPPlugin, GADBannerViewDelegate, GADInterstitialDelegate, GADRewardedAdDelegate {
    var bannerView: GADBannerView!
    var interstitial: GADInterstitial!
    var rewardedAd: GADRewardedAd!
    var personalizedAds: Bool!
    
    @objc func initialize(_ call: CAPPluginCall) {
        let appId = call.getString("appIdIos") ?? "ca-app-pub-6564742920318187~7217030993"
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        call.success([ "value": true ])
    }
    
    @objc func initializeWithConsent(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let appId = call.getString("appIdIos") ?? "ca-app-pub-6564742920318187~7217030993"
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            let pubId = call.getString("publisherId") ?? "pub-0123456789012345"
            PACConsentInformation.sharedInstance.requestConsentInfoUpdate(forPublisherIdentifiers: [pubId]) {(_ error: Error?) -> Void in
                if let error = error {
                    //Consent info update failed.
                    call.error("Consent Information failed to load:" + error.localizedDescription)
                } else {
                    var consentStatus: String;
                    //Consent info update succeeded.
                    if PACConsentInformation.sharedInstance.isRequestLocationInEEAOrUnknown {
                        if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.personalized {
                            self.personalizedAds = true
                            consentStatus = "PERSONALIZED"
                        } else if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.nonPersonalized {
                            self.personalizedAds = false
                            consentStatus = "NON_PERSONALIZED"
                        } else {
                            self.personalizedAds = false
                            consentStatus = "UNKNOWN"
                        }
                    } else {
                        consentStatus = "UNKNOWN"
                        self.personalizedAds = true
                    }
                    let object = [
                        "consentStatus": consentStatus,
                        "childDirected": "UNKNOWN",
                        "underAgeOfConsent": PACConsentInformation.sharedInstance.isTaggedForUnderAgeOfConsent,
                        "maxAdContentRating": GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating
                        ] as [String : Any]
                    call.success(object)
                }
            }
        }
    }
    
    @objc func showGoogleConsentForm(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let privacyURL = URL(string: call.getString("privacyPolicyURL") ?? "www.your.com/privacyurl"),
                let form = PACConsentForm(applicationPrivacyPolicyURL: privacyURL) else {
                    call.error("incorrect privacy URL")
                    return
            }
            form.shouldOfferPersonalizedAds = true
            form.shouldOfferNonPersonalizedAds = true
            form.shouldOfferAdFree = call.getBool("showAdFreeOption") ?? false
            form.load{(_ error: Error?) -> Void in
                if let error = error {
                    call.error(error.localizedDescription)
                } else {
                    form.present(from: self.bridge.viewController) {(_ error: Error?, userPrefersAdFree) in
                        if let error = error {
                            call.error(error.localizedDescription)
                        } else if userPrefersAdFree {
                            call.success(["consentStatus": "ADFREE"])
                        } else {
                            if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.unknown {
                                self.personalizedAds = false
                                call.success(["consentStatus": "UNKNOWN"])
                            } else if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.personalized {
                                self.personalizedAds = true
                                call.success(["consentStatus": "PERSONALIZED"])
                            } else if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.nonPersonalized {
                                self.personalizedAds = false
                                call.success(["consentStatus": "NON_PERSONALIZED"])
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func updateAdExtras(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var consentStatus = call.getString("consentStatus") ?? "UNKNOWN"
            if consentStatus == "PERSONALIZED" {
                self.personalizedAds = true
                PACConsentInformation.sharedInstance.consentStatus = .personalized
            } else if consentStatus == "NON_PERSONALIZED" {
                self.personalizedAds = false
                PACConsentInformation.sharedInstance.consentStatus = .nonPersonalized
            } else {
                self.personalizedAds = false
                PACConsentInformation.sharedInstance.consentStatus = .unknown
            }
            let childDirected = call.getString("childDirected") ?? "UNSPECIFIED"
            if childDirected == "TRUE"{
                GADMobileAds.sharedInstance().requestConfiguration.tag(forChildDirectedTreatment: true)
            } else if childDirected == "FALSE" {
                GADMobileAds.sharedInstance().requestConfiguration.tag(forChildDirectedTreatment: false)
            } else {
                // Don't tag
            }
            let underAgeOfConsent = call.getString("underAgeOfConsent") ?? "UNSPECIFIED"
            if underAgeOfConsent == "TRUE"{
                PACConsentInformation.sharedInstance.isTaggedForUnderAgeOfConsent = true
            } else if underAgeOfConsent == "FALSE" {
                PACConsentInformation.sharedInstance.isTaggedForUnderAgeOfConsent = false
            } else {
                // Don't tag
            }
            switch(call.getString("maxAdContentRating") ?? "MA") {
            case "G":
                GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
                break;
            case "PG":
                GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = GADMaxAdContentRating.parentalGuidance
                break;
            case "T":
                GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = GADMaxAdContentRating.teen
                break;
            default:
                GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = GADMaxAdContentRating.matureAudience
                break;
            }
            if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.unknown {
                consentStatus = "UNKNOWN"
                self.personalizedAds = false
            } else if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.personalized {
                self.personalizedAds = true
                consentStatus = "PERSONALIZED"
            } else if PACConsentInformation.sharedInstance.consentStatus == PACConsentStatus.nonPersonalized {
                self.personalizedAds = false
                consentStatus = "NON_PERSONALIZED"
            }
            let object = [
                "consentStatus": consentStatus,
                "childDirected": "UNKNOWN",
                "underAgeOfConsent": PACConsentInformation.sharedInstance.isTaggedForUnderAgeOfConsent,
                "maxAdContentRating": GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating
                ] as [String : Any]
            call.success(object)
        }
    }
    
    @objc func getAdProviders(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let adProviders: [PACAdProvider] = PACConsentInformation.sharedInstance.adProviders!
            var list = [[String: String]]()
            for item in adProviders {
                let object = [
                    "id": item.identifier.stringValue,
                    "name": item.name,
                    "privacyPolicyURL": item.privacyPolicyURL.absoluteString
                    ]
                list.append(object)
            }
            call.success(["adProviders": list])
        }
    }

    @objc func showBanner(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var adId = call.getString("adIdIos") ?? "ca-app-pub-3940256099942544/6300978111"
            let isTest = call.getBool("isTesting") ?? false
            if (isTest) {
                adId = "ca-app-pub-3940256099942544/6300978111";
            }
            let adSize = call.getString("adSize") ?? "SMART_BANNER"
            let adPosition = call.getString("adPosition") ?? "BOTTOM"
            let adBottomMargin = call.getInt("bottomMargin") ?? 0
            let adTopMargin = call.getInt("topMargin") ?? 0
            var bannerSize = kGADAdSizeBanner
            switch (adSize) {
            case "BANNER":
                bannerSize = kGADAdSizeBanner
                break;
            case "FLUID":
                bannerSize = kGADAdSizeSmartBannerPortrait
                break;
            case "FULL_BANNER":
                bannerSize = kGADAdSizeFullBanner
                break;
            case "LARGE_BANNER":
                bannerSize = kGADAdSizeLargeBanner
                break;
            case "LEADERBOARD":
                bannerSize = kGADAdSizeLeaderboard
                break;
            case "MEDIUM_RECTANGLE":
                bannerSize = kGADAdSizeMediumRectangle
                break;
            default:
                bannerSize = kGADAdSizeSmartBannerPortrait
                break;
            }

            self.bannerView = GADBannerView(adSize: bannerSize)
            self.addBannerViewToView(self.bannerView, adPosition, adBottomMargin, adTopMargin)
            self.bannerView.translatesAutoresizingMaskIntoConstraints = false
            self.bannerView.adUnitID = adId
            self.bannerView.rootViewController = UIApplication.shared.keyWindow?.rootViewController
            if self.personalizedAds == true {
                self.bannerView.load(GADRequest())
            } else {
                let request = GADRequest()
                let extras = GADExtras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
                self.bannerView.load(request)
            }
            self.bannerView.delegate = self

            call.success([ "value": true])
        }
    }

    @objc func hideBanner(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                if let subView = rootViewController.view.viewWithTag(2743243288699) {
                    NSLog("AdMob: find subView for hideBanner")
                    subView.isHidden = true;
                } else {
                    NSLog("AdMob: not find subView for resumeBanner for hideBanner")
                }
            }

            call.success([ "value": true ])
        }
    }

    @objc func resumeBanner(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                if let subView = rootViewController.view.viewWithTag(2743243288699) {
                    NSLog("AdMob: find subView for resumeBanner")
                    subView.isHidden = false;
                } else {
                    NSLog("AdMob: not find subView for resumeBanner")
                }
            }

            call.success([ "value": true ])
        }
    }

    @objc func removeBanner(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.removeBannerViewToView()
            call.success([ "value": true ])
        }
    }

    private func addBannerViewToView(_ bannerView: GADBannerView, _ adPosition: String, _ bottomMargin: Int, _ topMargin: Int) {
        removeBannerViewToView()
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            NSLog("AdMob: rendering rootView")
            var adBottomMargin = bottomMargin
            let adTopMargin = topMargin
            adBottomMargin = adBottomMargin * -1
            var position: NSLayoutConstraint.Attribute = .bottom
            switch (adPosition) {
            case "TOP":
                position = .top
                break;
            case "CENTER":
                // todo: position center
                position = .centerY
                break;
            default:
                position = .bottom
                break;
            }
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.tag = 2743243288699 // rand
            rootViewController.view.addSubview(bannerView)
            rootViewController.view.addConstraints(
                [NSLayoutConstraint(item: bannerView,
                                    attribute: position,
                                    relatedBy: .equal,
                                    toItem: rootViewController.view.safeAreaLayoutGuide,
                                    attribute: position,
                                    multiplier: 1,
                                    constant: CGFloat(adBottomMargin) + CGFloat(adTopMargin)),
                 NSLayoutConstraint(item: bannerView,
                                    attribute: .centerX,
                                    relatedBy: .equal,
                                    toItem: rootViewController.view,
                                    attribute: .centerX,
                                    multiplier: 1,
                                    constant: 0)
                ])
        }
    }

    private func removeBannerViewToView() {
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            if let subView = rootViewController.view.viewWithTag(2743243288699) {
                NSLog("AdMob: find subView")
                subView.removeFromSuperview()
            }
        }
    }


    /// Tells the delegate an ad request loaded an ad.
    public func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("adViewDidReceiveAd")
        self.notifyListeners("onBannerAdLoaded", data: ["value": true])
    }

    /// Tells the delegate an ad request failed.
    public func adView(_ bannerView: GADBannerView,
                didFailToReceiveAdWithError error: GADRequestError) {
        print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        self.notifyListeners("onBannerAdFailedToLoad", data: ["error": error.localizedDescription])
    }

    /// Tells the delegate that a full-screen view will be presented in response
    /// to the user clicking on an ad.
    public func adViewWillPresentScreen(_ bannerView: GADBannerView) {
        print("adViewWillPresentScreen")
        self.bridge.triggerJSEvent(eventName: "adViewWillPresentScreen", target: "window")
    }

    /// Tells the delegate that the full-screen view will be dismissed.
    public func adViewWillDismissScreen(_ bannerView: GADBannerView) {
        print("adViewWillDismissScreen")
        self.bridge.triggerJSEvent(eventName: "adViewWillDismissScreen", target: "window")
    }

    /// Tells the delegate that the full-screen view has been dismissed.
    public func adViewDidDismissScreen(_ bannerView: GADBannerView) {
        print("adViewDidDismissScreen")
        self.notifyListeners("onBannerAdClosed", data: ["value": true])
    }

    /// Tells the delegate that a user click will open another app (such as
    /// the App Store), backgrounding the current app.
    public func adViewWillLeaveApplication(_ bannerView: GADBannerView) {
        print("adViewWillLeaveApplication")
        self.notifyListeners("onBannerAdLeftApplication", data: ["value": true])
    }
    
    
    
    
    // Intertitial AD Implementation
    
    @objc func loadInterstitial(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var adId = call.getString("adIdIos") ?? "ca-app-pub-3940256099942544/4411468910"
            let isTesting = call.getBool("isTesting") ?? false
            if (isTesting) {
                adId = "ca-app-pub-3940256099942544/4411468910";
            }
            self.interstitial = GADInterstitial(adUnitID: adId)
            self.interstitial.delegate = self
            if self.personalizedAds == true{
                self.interstitial.load(GADRequest())
            } else {
                let request = GADRequest()
                let extras = GADExtras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
                self.interstitial.load(request)
            }
            call.success(["value": true])
        }
    }
    
    @objc func showInterstitial(_ call: CAPPluginCall) {
        
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                if self.interstitial.isReady {
                    self.interstitial.present(fromRootViewController: rootViewController)
                } else {
                    print("Ad wasn't ready")
                }
            }
            
            call.success(["value": true])
        }
        
    }
    
    // Intertitial Events Degigates
    /// Tells the delegate an ad request succeeded.
    public func interstitialDidReceiveAd(_ ad: GADInterstitial) {
        print("interstitialDidReceiveAd")
        self.notifyListeners("onInterAdLoaded", data: ["value": true])
    }

    /// Tells the delegate an ad request failed.
    public func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
        print("interstitial:didFailToReceiveAdWithError: \(error.localizedDescription)")
        self.notifyListeners("onInterAdFailedToLoad", data: ["error": error.localizedDescription])
    }

    /// Tells the delegate that an interstitial will be presented.
    public func interstitialWillPresentScreen(_ ad: GADInterstitial) {
        print("interstitialWillPresentScreen")
        self.notifyListeners("onInterAdOpened", data: ["value": true])
    }

    /// Tells the delegate the interstitial is to be animated off the screen.
    public func interstitialWillDismissScreen(_ ad: GADInterstitial) {
        print("interstitialWillDismissScreen")
    }

    /// Tells the delegate the interstitial had been animated off the screen.
    public func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        print("interstitialDidDismissScreen")
        self.notifyListeners("onInterAdClosed", data: ["value": true])
    }

    /// Tells the delegate that a user click will open another app
    /// (such as the App Store), backgrounding the current app.
    public func interstitialWillLeaveApplication(_ ad: GADInterstitial) {
        print("interstitialWillLeaveApplication")
        self.notifyListeners("onInterAdLeftApplication", data: ["value": true])
    }
    
    
    
    // Reward AD Implementation
    
    @objc func loadRewarded(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var adId: String = call.getString("adIdIos") ?? "ca-app-pub-3940256099942544/1712485313"
            let isTesting = call.getBool("isTesting") ?? false
            if (isTesting) {
                adId = "ca-app-pub-3940256099942544/1712485313";
            }
            self.rewardedAd = GADRewardedAd(adUnitID: adId)
            if self.personalizedAds == true{
                self.rewardedAd?.load(GADRequest()) { error in
                    if let error = error {
                      print("Loading failed: \(error)")
                        call.error("Loading failed")
                    } else {
                      print("Loading Succeeded")
                        call.success(["value": true])
                    }
                }
            } else {
                let request = GADRequest()
                let extras = GADExtras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
                self.rewardedAd?.load(request) { error in
                    if let error = error {
                      print("Loading failed: \(error)")
                        call.error("Loading failed")
                    } else {
                      print("Loading Succeeded")
                        call.success(["value": true])
                    }
                }
            }
        }
    }
    
    @objc func showRewarded(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                if self.rewardedAd?.isReady == true {
                    self.rewardedAd?.present(fromRootViewController: rootViewController, delegate: self)
                    call.resolve([ "value": true ])
                } else {
                    call.error("Reward Video is Not Ready Yet")
                }
            }
            
        }
    }
    
    /// Tells the delegate that the user earned a reward.
    public func rewardedAd(_ rewardedAd: GADRewardedAd, userDidEarn reward: GADAdReward) {
        print("Reward received with currency: \(reward.type), amount \(reward.amount).")
        self.notifyListeners("onRewarded", data: ["type": reward.type, "amount": reward.amount])
    }
    /// Tells the delegate that the rewarded ad was presented.
    public func rewardedAdDidPresent(_ rewardedAd: GADRewardedAd) {
        print("Rewarded ad presented.")
        self.notifyListeners("onRewardedVideoAdOpened", data: ["value": true])
    }
    /// Tells the delegate that the rewarded ad was dismissed.
    public func rewardedAdDidDismiss(_ rewardedAd: GADRewardedAd) {
        print("Rewarded ad dismissed.")
        self.notifyListeners("onRewardedVideoAdClosed", data: ["value": true])
    }
    /// Tells the delegate that the rewarded ad failed to present.
    public func rewardedAd(_ rewardedAd: GADRewardedAd, didFailToPresentWithError error: Error) {
        print("Rewarded ad failed to present.")
        self.notifyListeners("onRewardedVideoAdFailedToLoad", data: ["error": error.localizedDescription])
    }

}





