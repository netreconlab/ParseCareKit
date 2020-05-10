# ParseCareKit
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/netreconlab/ParseCareKit/#license) ![Swift](https://img.shields.io/badge/swift-5.0-brightgreen.svg) ![Xcode 11.0+](https://img.shields.io/badge/Xcode-11.0%2B-blue.svg) ![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue.svg) [![Version](https://img.shields.io/cocoapods/v/ParseCareKit.svg?style=flat)](https://cocoapods.org/pods/ParseCareKit)

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance. Look at hipaa-mongo and [hipaa_mongo](https://github.com/netreconlab/hipaa_mongodb) and [hipaa-postges]()(will post soon) to get started with HIPAA compliant databases that can be configured with pare-server. An example of how to use parse-server with [postgres](https://www.postgresql.org) and [parse-dashboard](https://github.com/parse-community/parse-dashboard) can be found at [parse-postgres](https://github.com/netreconlab/parse-postgres). 

## Install ParseCareKit
The framework currently isn't SPM compatible yet as it's depedendent on [Parse](https://github.com/parse-community/Parse-SDK-iOS-OSX) which is currently only compatible with cocoapods. 

### Installing via cocoapods
The easiest way to install is via cocoapods. Since ParseCareKit requires CareKit, and CareKit doesn't officially support cocoapods (see more [here](https://github.com/carekit-apple/CareKit/issues/383)), you will have to point to a github repo that contains CareKit 2.0+ podspecs. Feel free to point to the repo below which mirrors the most up-to-date versions of CareKit. Your podfile should contain at least the following:

```ruby
platform :ios, '13.0' #This is the minimum requirement for CareKit 2.0

target 'MyApp' do #Change to your app name
  use_frameworks!

  # All of these are required to run ParseCareKit
  pod 'CareKitUI', :git => 'https://github.com/cbaker6/CareKit.git', :branch => 'pod'
  pod 'CareKitStore', :git => 'https://github.com/cbaker6/CareKit.git', :branch => 'pod'
  pod 'CareKit', :git => 'https://github.com/cbaker6/CareKit.git', :branch => 'pod'
  pod 'ParseCareKit', :git => 'https://github.com/netreconlab/ParseCareKit.git', :branch => 'master'
  
  # Add the rest of your pods below
end
```

The above podspec will also install the minimum required [Parse iOS framework](https://github.com/parse-community/Parse-SDK-iOS-OSX)(and its dependencies) as it's also a requirement for ParseCareKit.

### Installing as a framework
- Fork the project
- Build the project
- In your project Targets, click your corresponding target and then click the `General` heading to the right
- Place `ParseCareKit.framework` in `Frameworks, Libraries, and Embedded Content` and it should automatically appear in `Linked Binary with Libraries` under the `Build Phases` section
- Then, simply place `import ParseCareKit` at the top of any file that needs the framework.

**If you have CareKit already in your project via SPM or copied, you will need to remove it as ParseCareKit comes with the a compatibile version of CareKit and a conflict of CareKit appearing twice will cause your app to crash**

## Installing ParseSDK-iOS-MacOS
Follow the [guide](https://docs.parseplatform.org/ios/guide/) for directions on installing the iOS SDK. It should be straight forward with cocoapods. 

## Setup Parse Server
For details on how to setup parse-server, follow the directions [here](https://github.com/parse-community/parse-server#getting-started) or look at their detailed [guide](https://docs.parseplatform.org/parse-server/guide/). Note that standard deployment locally on compouter, docker, AWS, Google Cloud, isn't HIPAA complaint by default. 

## Synchronizing Your Data
Assuming you are already familiar with [CareKit](https://github.com/carekit-apple/CareKit) (look at their documentation for details). Using ParseCareKit is simple, especially if you are using `OCKStore` out-of-the-box. If you are using a custom `OCKStore` you will need to subclass and write some additional code to synchronize your care-store with parse-server.

ParseCareKit stays synchronized with the `OCKStore` by leveraging `OCKSynchronizedStoreManager`. Once your care-store is setup, simply pass an instance of `OCKSynchronizedStoreManager` to [ParseSynchronizedStoreManager](https://github.com/netreconlab/ParseCareKit/blob/master/ParseCareKit/ParseSynchronizedStoreManager.swift). I recommend having this as a singleton, as it can handle all syncs from the carestore from here. An example is below:

```swift
let dataStore = OCKStore(name: "myDataStore", type: .onDisk)
let dataStoreManager = OCKSynchronizedStoreManager(wrapping: dataStore)
let cloudStoreManager = ParseSynchronizedStoreManager(dataStoreManager)
```

During initialization of `ParseSynchronizedStoreManager`, all CareKit data that has `remoteID == nil` will automatically be synced to your parse-server, once synced, the `remoteID` for each entity will be replaced by the corresponding `objectId` on your parse-server.

** Note that only the latest state of an OCK entity is synchronized to parse-server. The parse-server doesn't maintain the versioned data like the local OCKStore. If you want this functionality, you will have to develop it as the framework doesn't support it, and parse-server queries are not setup for this. **

The mapping from CareKit -> Parse tables/classes are as follows:
* OCKPatient <-> User - Note that by default of this framework, any "user" (doctor, patient, caregiver, etc.) is an `OCKPatient` and will have a corresponding record in your Parse `User` table.
* OCKCarePlan <-> CarePlan
* OCKTask <-> Task
* OCKContact <-> Contact
* OCKOutcome <-> Outcome
* OCKOutcomeValue <-> OutcomeValue
* OCKScheduleElement <-> ScheduleElement
* OCKNote <-> Note

To create a Parse object from a CareKit object:

```swift
let newCarePlan = OCKCarePlan(id: "uniqueId", title: "New Care Plan", patientID: nil)
let _ = User(careKitEntity: newCarePlan, storeManager: dataStoreManager){
    copiedToParseObject in
                    
    guard let parseCarePlan = copiedToParseObject else{
        print("Error copying OCKCarePlan")
        return
    }
}
```

To create a CareKit object from a Parse object:

```swift
guard let careKitCarePlan = parseCarePlan.convertToCareKit() else{
  print("Error converting to CareKit object")
  return
}

dataStoreManager.store.addAnyCarePlan(patient, callbackQueue: .main){
    result in

    switch result{
    case .success(let savedCareKitCarePlan):
        print("patient \(savedCareKitCarePlan) saved successfully")
        
        //Note that since the "cloudStoreManager" singleton is still alive, it will automatically sync your new CarePlan to Parse. There is no need to save the Parse object directly. I recommend letting "ParseSynchronizedStoreManager" sync all of your data to Parse instead of saving your own objects (with the exception of signing up a User, which I show later)
    case .failure(let error):
        print("Error savinf OCKCarePlan. \(error)")
    }
}
```

Signing up a `User` and then using them as an `OCKPatient` is a slightly different process due to you needing to let Parse properly sign in the user (verifying credentials, creating tokens, etc) before saving them to the `OCKStore`. An example is below:

```swift
let newParsePatient = User()
newParsePatient.username = uniqueUsername
newParsePatient.password = "strongPassword"
newParsePatient.email = "email@netreconlab.cs.uky.edu"

newParsePatient.signUpInBackground{
    (success, error)->Void in
    if (success == true){
        print("Sign Up successfull")
    
        guard let signedInPatient = User.current() else{
            //Something went wrong with signing up this user
            print(Error signing in \(error))
            return
        }
        
        //... fill in the rest of the signedInPatient attributes
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = firstName
        nameComponents.familyName = lastName
        let name = CareKitParsonNameComponents.familyName.convertToDictionary(nameComponents)
        signedInPatient.name = name
        
        signedInPatient.uuid = UUID().uuidString
        signedInPatient.tags = [signedInPatient.uuid]
        
        guard let careKitPatient = signedInPatient.convertToCareKit() else{
          print("Error converting to CareKit object")
          return
        }
        
        dataStoreManager.store.addAnyPatient(careKitPatient, callbackQueue: .main){
        result in

        switch result{
        case .success(let savedCareKitPatient):
            print("Your new patient \(savedCareKitPatient) is saved to OCKStore locally and synced to your Parse Server")
        case .failure(let error):
            print("Error savinf OCKCarePlan. \(error)")
        }
    else{
        print("Parse had trouble signing in user with error: \(error)")
    }    
}
```

There will be times you need to customize entities by adding fields that are different from the standard CareKit entity fields. If the fields you want to add can be converted to strings, it is recommended to take advantage of the `userInfo: [String:String]` field of a CareKit entity. To do this, you simply need to subclass the entity you want customize and override methods such as `copyCareKit(...)`, `convertToCarekit()`. For example, below shows how to add fields to OCKPatient<->User:

```swift
class AppUser: User{
    @NSManaged public var primaryCondition:String?
    @NSManaged public var comorbidities:String?
    
    override func copyCareKit(_ patientAny: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager, completion: @escaping (User?) -> Void) {
        
        guard let patient = patientAny as? OCKPatient else{
            completion(nil)
            return
        }
        
        super.copyCareKit(patientAny, storeManager: storeManager){
            _ in
            self.primaryCondition = patient.userInfo?[kPCKPatientUserInfoPrimaryConditionKey]
            self.comorbidities = patient.userInfo?[kPCKPatientUserInfoComorbiditiesKey]
            completion(self)
        }
    }
    
    override func convertToCareKit() -> OCKPatient? {
        var partiallyConvertedUser = super.convertToCareKit()
        var userInfo = [String:String]()
        if let primaryCondition = self.primaryCondition{
            userInfo[kPCKPatientUserInfoPrimaryConditionKey] = primaryCondition
        }
        if let comorbidities = self.comorbidities{
            userInfo[kPCKPatientUserInfoComorbiditiesKey] = comorbidities
        }
        partiallyConvertedUser?.userInfo = userInfo
        return partiallyConvertedUser
    }
}
```
Of course, you can custimize further by implementing your copyCareKit and converToCareKit methods and not call the super methods.

If you have a custom store, and have created your own entities, you simply need to conform to the `PCKSynchronizedEntity` protocol which will require you to subclass `PFObject` and conform to `PFSubclassing`. You should also create methods for your custom entity such as `addToCloudInBackground,updateCloudEventually,deleteFromCloudEventually` and properly subclass `ParseSynchronizedStoreManager`, overiding the necessary methods. You can look through the entities like `User` and `CarePlan` as a reference for builfing your own. 
