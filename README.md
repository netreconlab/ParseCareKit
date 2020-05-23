# ParseCareKit
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/netreconlab/ParseCareKit/#license) ![Swift](https://img.shields.io/badge/swift-5.0-brightgreen.svg) ![Xcode 11.0+](https://img.shields.io/badge/Xcode-11.0%2B-blue.svg) ![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue.svg) [![Version](https://img.shields.io/cocoapods/v/ParseCareKit.svg?style=flat)](https://cocoapods.org/pods/ParseCareKit)

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance. Look at hipaa-mongo and [hipaa_mongo](https://github.com/netreconlab/hipaa_mongodb) and [hipaa-postges]()(will post soon) to get started with HIPAA compliant databases that can be configured with pare-server. An example of how to use parse-server with [postgres](https://www.postgresql.org) and [parse-dashboard](https://github.com/parse-community/parse-dashboard) can be found at [parse-postgres](https://github.com/netreconlab/parse-postgres). 

## What versions of ParseCareKit Suits Your Needs?
- (Most cases) Need to use ParseCareKit for iOS13+ and will be using [CareKit](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore`) within your app? You should use the [master](https://github.com/netreconlab/ParseCareKit) branch. You can take advantage of all of the capabilities of ParseCareKit. You should use `ParseRemoteSynchronizationManager()` see [below](#synchronizing-your-data) more details.
- Need to use ParseCareKit for iOS13+ and will be using [CareKit](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (but you created your own store conforming to the `OCKAnyStoreProtocol`) within your app? You should use the [master](https://github.com/netreconlab/ParseCareKit) branch. You can still use most of the capabilities of ParseCareKit, but you will be limited to syncing via a "wall clock" instead of "knowledge vectors". You should use `ParseSynchronizedStoreManager()` see [below](#synchronizing-your-data) more details.
- Need to use ParseCareKit for iOS11+ and will be using [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore`) within your app? You should use the [carestore](https://github.com/netreconlab/ParseCareKit/tree/carestore) branch. You can take advantage of all of the capabilities of ParseCareKit. You should use `ParseRemoteSynchronizationManager()` see [below](#synchronizing-your-data) more details. The limitation here is that CareKit and CareKitUI can't be use because they require iOS13.

**Note that it is recommended to use Knowledge Vectors (`ParseRemoteSynchronizationManager`) over Wall Clocks (`ParseSynchronizedStoreManager`) as the latter can run into more synching issues. If you choose to go the wall clock route, I recommend having your application suited for 1 device per user to reduce potential synching issues. You can learn more about how Knowledge Vectors work by looking at [vector clocks](https://en.wikipedia.org/wiki/Vector_clock).**

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
  pod 'CareKitStore', :git => 'https://github.com/cbaker6/CareKit.git', :branch => 'pod_vector'
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

### Protecting Patients data in the Cloud using ACL's
You should set the default access for information you placed on your parse-server using ParseCareKit. To do this, you can set the default read/write access for all classes. For example, to make all data created to only be read and written by the user who created at do the following in your AppDelegate:

```swift
PFUser.enableRevocableSessionInBackground() //Allow sessions to be revovked from the cloud

//Set default ACL for all Classes
let defaultACL = PFACL()
defaultACL.hasPublicReadAccess = false
defaultACL.hasPublicWriteAccess = false
PFACL.setDefault(defaultACL, withAccessForCurrentUser:true)
```

When giving access to a CareTeam or other entities, special care should be taken when deciding the propper ACL or Role. Feel free to read more about [ACLs](https://docs.parseplatform.org/ios/guide/#security-for-user-objects) and [Role](https://docs.parseplatform.org/ios/guide/#roles) access in Parse.

## Synchronizing Your Data
Assuming you are already familiar with [CareKit](https://github.com/carekit-apple/CareKit) (look at their documentation for details). Using ParseCareKit is simple, especially if you are using `OCKStore` out-of-the-box. If you are using a custom `OCKStore` you will need to subclass and write some additional code to synchronize your care-store with parse-server.

ParseCareKit stays synchronized with the `OCKStore` by leveraging `OCKSynchronizedStoreManager`. Once your care-store is setup, simply pass an instance of `OCKSynchronizedStoreManager` to [ParseSynchronizedStoreManager](https://github.com/netreconlab/ParseCareKit/blob/master/ParseCareKit/ParseSynchronizedStoreManager.swift). I recommend having this as a singleton, as it can handle all syncs from the carestore from here. An example is below:

```swift
/*Use KnowledgeVector and OCKRemoteSynchronizable to keep data synced. 
This works with 1 or many devices per patient. Currently this only syncs OCKTask and OCKOutcome*/
let remoteStoreManager = ParseRemoteSynchronizationManager()
let dataStore = OCKStore(name: "myDataStore", type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self //Conform to this protocol if you are writing custom CloudCode in Parse and want to push syncs
remoteStoreManager.parseRemoteDelegate = self //Conform to this protocol to resolve conflicts
remoteStoreManager.startSynchronizing(dataStore) //Required to pass in the OCKStore, this autosyncs
//remoteStoreManager.startSynchronizing(dataStore, auto: false) //Use this if you want to manually control synchs

/*Use wall clock and OCKSynchronizedStoreManager to keep data synced. Useful if you are using CareKit 2.0.1 or below
This should only be used if there's 1 device per patient or
if all of a patients devices are on the same clock or else they may get out-of-sync*/
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
* OCKRevisionRecord.KnowledgeVector <-> KnowledgeVector

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

dataStoreManager.store.addAnyCarePlan(careKitCarePlan, callbackQueue: .main){
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
        
        /* This is mandatory as it's used for querying the CareStore and linking to Parse
            The entityId (Parse) shares a 1 to 1 relationship with id (CareKit)
        */
        signedInPatient.entityId = UUID().uuidString 
        
        //How to add names
        var nameComponents = PersonNameComponents() 
        nameComponents.givenName = firstName
        nameComponents.familyName = lastName
        let name = CareKitParsonNameComponents.familyName.convertToDictionary(nameComponents)
        signedInPatient.name = name
        
        //This is suggested so you can query if needed
        signedInPatient.tags = [signedInPatient.entityId] 
        
        /*Save the updated info to Parse, after, you should make all changes and saves to the CareStore
        and let ParseCareKit sync instead of saving to Parse directly
        */
        signedInPatient.saveInBackground(){
            (success,error) in
            if !success{
                if error != nil{
                    print("Error saving to Parse: \(error!)")
                }else{
                    print("Error saving to Parse: Error unknown")
                }
            }else{
                //Conver Parse to CareKit
                guard let careKitPatient = signedInPatient.convertToCareKit(firstTimeLoggingIn: true) else{
                  print("Error converting to CareKit object")
                  return
                }
                
                //Save the CareKit user to the CareStore
                dataStoreManager.store.addAnyPatient(careKitPatient, callbackQueue: .main){
                    result in

                    switch result{
                    case .success(let savedCareKitPatient):
                        print("Your new patient \(savedCareKitPatient) is saved to OCKStore locally and synced to your Parse Server")
                        case .failure(let error):
                        print("Error savinf OCKCarePlan. \(error)")
                    }
                }
            }
        }
    }else{
        print("Parse had trouble signing in user with error: \(error)")
    }    
}
```

There will be times you need to customize entities by adding fields that are different from the standard CareKit entity fields. If the fields you want to add can be converted to strings, it is recommended to take advantage of the `userInfo: [String:String]` field of a CareKit entity. To do this, you simply need to subclass the entity you want customize and override methods such as `copyCareKit(...)`, `convertToCarekit()`. For example, below shows how to add fields to OCKPatient<->User:

```swift
class AppUser: User{
    @NSManaged public var primaryCondition:String?
    @NSManaged public var comorbidities:String?
    
    override copyCareKit(_ patientAny: OCKAnyPatient, clone:Bool)-> User? {
        
        guard let patient = patientAny as? OCKPatient else{
            completion(nil)
            return
        }
        _ = super.copyCareKit(patient, clone: clone)
        self.primaryCondition = patient.userInfo?["CustomPatientUserInfoPrimaryConditionKey"]
        self.comorbidities = patient.userInfo?["CustomPatientUserInfoComorbiditiesKey"]
        return self
    }
    
    override func convertToCareKit(firstTimeLoggingIn: Bool=false) -> OCKPatient? {
        guard var partiallyConvertedUser = super.convertToCareKit(firstTimeLoggingIn: firstTimeLoggingIn) else{return nil}
        
        var userInfo: [String:String]!
        if partiallyConvertedUser.userInfo == nil{
            userInfo = [String:String]()
        }else{
            userInfo = partiallyConvertedUser.userInfo!
        }
        if let primaryCondition = self.primaryCondition{
            userInfo["CustomPatientUserInfoPrimaryConditionKey"] = primaryCondition
        }
        if let comorbidities = self.comorbidities{
            userInfo["CustomPatientUserInfoComorbiditiesKey"] = comorbidities
        }
        partiallyConvertedUser?.userInfo = userInfo
        return partiallyConvertedUser
    }
}
```
Of course, you can custimize further by implementing your copyCareKit and converToCareKit methods and not call the super methods.

If you have a custom store, and have created your own entities, you simply need to conform to the `PCKSynchronizedEntity` protocol which will require you to subclass `PFObject` and conform to `PFSubclassing`. You should also create methods for your custom entity such as `addToCloud,updateCloud,deleteFromCloud` and properly subclass `ParseSynchronizedStoreManager`, overiding the necessary methods. You can look through the entities like `User` and `CarePlan` as a reference for builfing your own. 
