# ParseCareKit
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/netreconlab/ParseCareKit/#license) ![Swift](https://img.shields.io/badge/swift-5.0-brightgreen.svg) ![Xcode 11.0+](https://img.shields.io/badge/Xcode-11.0%2B-blue.svg) ![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue.svg) [![Version](https://img.shields.io/cocoapods/v/ParseCareKit.svg?style=flat)](https://cocoapods.org/pods/ParseCareKit)

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). 

For the backend, it is suggested to use [parse-hipaa](https://github.com/netreconlab/parse-hipaa) which is an out-of-the-box HIPAA compliant Parse/[Postgres](https://www.postgresql.org) or Parse/[Mongo](https://www.mongodb.com) server that comes with [Parse Dashboard](https://github.com/parse-community/parse-dashboard). Since [parse-hipaa](https://github.com/netreconlab/parse-hipaa) is a pare-server, it can be used for iOS, Android, and web based apps. API's such as [GraphQL](https://graphql.org), REST, and JS are also enabled in parse-hipaa and can be accessed directly or via the "API Console" in parse-dashboard. See the [Parse SDK documentation](https://parseplatform.org/#sdks) for details. These docker images include the necessary database auditing and logging for HIPAA compliance.


You can also use ParseCareKit with any parse-server setup. Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance.

The following CareKit Entities are synchronized with Parse tables/classes:
- [x] OCKPatient <-> Patient
- [x] OCKCarePlan <-> CarePlan
- [x] OCKTask <-> Task
- [x] OCKContact <-> Contact
- [x] OCKOutcome <-> Outcome
- [x] OCKOutcomeValue <-> OutcomeValue
- [x] OCKScheduleElement <-> ScheduleElement
- [x] OCKNote <-> Note
- [x] OCKRevisionRecord.KnowledgeVector <-> KnowledgeVector


## CareKit Sample App with ParseCareKit
A sample app, [CareKitSample-ParseCareKit](https://github.com/netreconlab/CareKitSample-ParseCareKit), connects to the aforementioned [parse-hipaa](https://github.com/netreconlab/parse-hipaa) and demonstrates how CareKit data can be easily synched to the Cloud using ParseCareKit.

## What version of ParseCareKit Suits Your Needs?
- (Most cases) Need to use ParseCareKit for iOS13+ and will be using [CareKit](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore`) within your app? You should use the [master](https://github.com/netreconlab/ParseCareKit) branch. You can take advantage of all of the capabilities of ParseCareKit. You should use `ParseRemoteSynchronizationManager()` see [below](#synchronizing-your-data) more details.
- Need to use ParseCareKit for iOS13+ and will be using [CareKit](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (but you created your own store conforming to the `OCKAnyStoreProtocol`) within your app? You should use the [master](https://github.com/netreconlab/ParseCareKit) branch. You can still use most of the capabilities of ParseCareKit, but you will be limited to syncing via a "wall clock" instead of "knowledge vectors". You should use `ParseSynchronizedStoreManager()` see [below](#synchronizing-your-data) more details.
- Need to use ParseCareKit for iOS11+ and will be using [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore`) within your app? You should use the [carestore](https://github.com/netreconlab/ParseCareKit/tree/carestore) branch. You can take advantage of all of the capabilities of ParseCareKit. You should use `ParseRemoteSynchronizationManager()` see [below](#synchronizing-your-data) more details. The limitation here is that CareKit and CareKitUI can't be use because they require iOS13.
- Need to use ParseCareKit for iOS13+ and will be using [CareKit <= 2.0.1](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI <= 2.0.1](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore <= 2.0.1](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore` or conforming to `OCKAnyStoreProtocol`) within your app? You should use the [carekit_2.0.1](https://github.com/netreconlab/ParseCareKit/tree/carekit_2.0.1) branch. You can still use most of the capabilities of ParseCareKit, but you will be limited to syncing via a "wall clock" instead of "knowledge vectors". You should use `ParseSynchronizedStoreManager()` see [below](#synchronizing-your-data) more details.

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

### Using vector clocks aka CareKits KnowledgeVector (`ParseRemoteSynchronizationManager`)

ParseCareKit stays synchronized with the `OCKStore` by leveraging `OCKRemoteSynchronizable`.  I recommend having this as a singleton, as it can handle all syncs from the carestore from here. An example is below:

```swift
/*Use KnowledgeVector and OCKRemoteSynchronizable to keep data synced. 
This works with 1 or many devices per patient.*/
let remoteStoreManager = ParseRemoteSynchronizationManager(uuid: uuid, auto: true)
let dataStore = OCKStore(name: "myDataStore", type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self //Conform to this protocol if you are writing custom CloudCode in Parse and want to push syncs
remoteStoreManager.parseRemoteDelegate = self //Conform to this protocol to resolve conflicts
```

The `uuid` being passed to `ParseRemoteSynchronizationManager` is used for the KnowledgeVector. A possibile solution that allows for high flexibity is to have 1 of these per user-type per user. This allows you to have have one `PFUser` that can be a "Doctor" and a "Patient". You should generate a different uuid for this particular PFUser's `Doctor` and `Patient` type. You can save all types to PFUser:

```swift
let userTypeUUIDDictionary = [
"doctor": UUID().uuidString,
"patient": UUID().uuidString
]

//Store the possible uuids for each type
PFUser.current().userTypes = userTypeUUIDDictionary //Note that you need to save the UUID in string form to Parse
PFUser.current().loggedInType = "doctor" 
PFUser.current().saveInBackground()

//Start synch with the correct knowlege vector for the particular type of user
let lastLoggedInType = PFUser.current().loggedInType
let userTypeUUIDString = PFUser.current().userTypes[lastLoggedInType] as! String
let userTypeUUID = UUID(uuidString: userTypeUUID)!

//Start synching 
let remoteStoreManager = ParseRemoteSynchronizationManager(uuid: userTypeUUID, auto: true)
let dataStore = OCKStore(name: "myDataStore", type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self //Conform to this protocol if you are writing custom CloudCode in Parse and want to push syncs
remoteStoreManager.parseRemoteDelegate = self //Conform to this protocol to resolve conflicts
```

Register as a delegate just in case ParseCareKit needs your application to update a CareKit entity. ParseCareKit doesn't have access to your CareKitStor, so your app will have to make the necessary update if ParseCareKit detects a problem and needs to make an update locally. Registering for the delegates also allows you to handle synching conflicts. An example is below:


```swift
extension AppDelegate: OCKRemoteSynchronizationDelegate, ParseRemoteSynchronizationDelegate{
    func didRequestSynchronization(_ remote: OCKRemoteSynchronizable) {
        print("Implement")
    }
    
    func remote(_ remote: OCKRemoteSynchronizable, didUpdateProgress progress: Double) {
        print("Implement")
    }
    
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        let conflictPolicy = OCKMergeConflictResolutionPolicy.keepDevice
        completion(conflictPolicy)
    }
    
    func storeUpdatedOutcome(_ outcome: OCKOutcome) {
        //This is a workaround for a CareKit bug that doesn't allow you to query by id
        store.updateOutcome(outcome, callbackQueue: .global(qos: .background)){
            results in
            switch results{
            
            case .success(_):
                store.synchronize(){_ in} //Force synchronize after fix
            case .failure(let error):
                print("Error storing fix \(error)")
            }
        }
    }
    
    func storeUpdatedCarePlan(_ carePlan: OCKCarePlan) {
        dataStore.updateAnyCarePlan(carePlan, callbackQueue: .global(qos: .background), completion: nil)
    }
    
    func storeUpdatedContact(_ contact: OCKContact) {
        dataStore.updateAnyContact(contact, callbackQueue: .global(qos: .background), completion: nil)
    }
    
    func storeUpdatedPatient(_ patient: OCKPatient) {
        dataStore.updateAnyPatient(patient, callbackQueue: .global(qos: .background), completion: nil)
    }
    
    func storeUpdatedTask(_ task: OCKTask) {
        dataStore.updateAnyTask(task, callbackQueue: .global(qos: .background), completion: nil)
    }
}

```

### Using the wall clock (`ParseSynchronizedStoreManager`)

You can also use ParseCareKit to stay synchronized with the `OCKStore` or `OCKAnyStoreProtocol` by leveraging `OCKSynchronizedStoreManager`. Once your care-store is setup, simply pass an instance of `OCKSynchronizedStoreManager` to [ParseSynchronizedStoreManager](https://github.com/netreconlab/ParseCareKit/blob/master/ParseCareKit/ParseSynchronizedStoreManager.swift). I recommend having this as a singleton, as it can handle all syncs from the carestore from here. An example is below:

```swift
/*Use wall clock and OCKSynchronizedStoreManager to keep data synced. Useful if you are using CareKit 2.0.1 or below
This should only be used if there's 1 device per patient or
if all of a patients devices are on the same clock or else they may get out-of-sync*/
let dataStore = OCKStore(name: "myDataStore", type: .onDisk)
let dataStoreManager = OCKSynchronizedStoreManager(wrapping: dataStore)
let cloudStoreManager = ParseSynchronizedStoreManager(dataStoreManager)
```

During initialization of `ParseSynchronizedStoreManager`, all CareKit data that has `remoteID == nil` will automatically be synced to your parse-server, once synced, the `remoteID` for each entity will be replaced by the corresponding `objectId` on your parse-server.

To create a Parse object from a CareKit object:

```swift
let newCarePlan = OCKCarePlan(id: "uniqueId", title: "New Care Plan", patientID: nil)
let parseCarePlan = CarePlan(careKitEntity: newCarePlan)
```

To create a CareKit object from a Parse object:

```swift
guard let careKitCarePlan = parseCarePlan.convertToCareKit() else{
  print("Error converting to CareKit object")
  return
}

store.addCarePlan(careKitCarePlan, callbackQueue: .main){
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

There will be times you need to customize entities by adding fields that are different from the standard CareKit entity fields. If the fields you want to add can be converted to strings, it is recommended to take advantage of the `userInfo: [String:String]` field of a CareKit entity. To do this, you simply need to subclass the entity you want customize and override all of the methods below `new()`,  `copyCareKit(...)`, `convertToCarekit()`. For example, below shows how to add fields to OCKPatient<->Patient:

```swift
class CancerPatient: Patient{
    @NSManaged public var primaryCondition:String?
    @NSManaged public var comorbidities:String?
    
    override func new() -> PCKSynchronized {
        return CancerPatient()
    }
    
    override func new(with careKitEntity: OCKEntity)->PCKSynchronized? {
        
        switch careKitEntity {
        case .patient(let entity):
            return CancerPatient(careKitEntity: entity)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    override copyCareKit(_ patientAny: OCKAnyPatient)-> Patient? {
        
        guard let cancerPatient = patientAny as? OCKPatient else{
            completion(nil)
            return
        }
        
        _ = super.copyCareKit(cancerPatient, clone: clone){
        self.primaryCondition = cancerPatient.userInfo?["CustomPatientUserInfoPrimaryConditionKey"]
        self.comorbidities = cancerPatient.userInfo?["CustomPatientUserInfoComorbiditiesKey"]
    }
    
    override func convertToCareKit(fromCloud: Bool=false) -> OCKPatient? {
        guard var partiallyConvertedPatient = super.convertToCareKit(fromCloud: fromCloud) else{return nil}
        
        var userInfo: [String:String]!
        if partiallyConvertedPatient.userInfo == nil{
            userInfo = [String:String]()
        }else{
            userInfo = partiallyConvertedPatient.userInfo!
        }
        if let primaryCondition = self.primaryCondition{
            userInfo["CustomPatientUserInfoPrimaryConditionKey"] = primaryCondition
        }
        if let comorbidities = self.comorbidities{
            userInfo["CustomPatientUserInfoComorbiditiesKey"] = comorbidities
        }
        partiallyConvertedPatient?.userInfo = userInfo
        return partiallyConvertedPatient
    }
}
```

Then you need to pass your custom class when initializing `ParseRemoteSynchronizingManager`. The way to do this is below:

```swift
let updatedConcreteClasses: [PCKStoreClass: PCKRemoteSynchronized] = [
    .patient: CancerPatient()
]

remoteStoreManager = ParseRemoteSynchronizationManager(uuid: uuid, auto: true, replacePCKStoreClasses: updatedConcreteClasses)
dataStore = OCKStore(name: storeName, type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self
remoteStoreManager.parseRemoteDelegate = self
```


Of course, you can customize further by implementing your copyCareKit and converToCareKit methods and not call the super methods.


You can also map "custom" `Parse` classes to concrete `OCKStore` classes. This is useful when you want to have `Doctor`'s and `Patient`'s in the same app, but would like to map them both locally to the `OCKPatient` table on iOS devices.  ParseCareKit makes this simple. Follow the same process as creating `CancerPatient` above, but add the `kPCKCustomClassKey` key to `userInfo` with `Doctor.parseClassName()` as the value. See below:

```swift
class Doctor: Patient{
    @NSManaged public var type:String?
    
    override func new() -> PCKSynchronized {
        return Doctor()
    }
    
    override func new(with careKitEntity: OCKEntity)-?PCKSynchronized? {
        
        switch careKitEntity {
        case .patient(let entity):
            return Doctor(careKitEntity: entity)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    //Add a convienience initializer to to ensure that that the doctor class is always created correctly
    convenience init(careKitEntity: OCKAnyPatient {
        self.init()
        self.copyCareKit(careKitEntity)
        self.userInfo = [kPCKCustomClassKey: self.parseClassName]
    }
    
    override copyCareKit(_ patientAny: OCKAnyPatient)->Patient? {
        
        guard let doctor = patientAny as? OCKPatient else{
            return nil
        }
        
        super.copyCareKit(doctor, clone: clone)
        self.type = cancerPatient.userInfo?["CustomDoctorUserInfoTypeKey"]
        return seld
    }
    
    override func convertToCareKit(fromCloud: Bool=false) -> OCKPatient? {
        guard var partiallyConvertedDoctor = super.convertToCareKit(fromCloud: fromCloud) else{return nil}
        
        var userInfo: [String:String]!
        if partiallyConvertedDoctor.userInfo == nil{
            userInfo = [String:String]()
        }else{
            userInfo = partiallyConvertedDoctor.userInfo!
        }
        if let type = self.type{
            userInfo["CustomDoctorUserInfoTypeKey"] = type
        }
        
        partiallyConvertedDoctor?.userInfo = userInfo
        return partiallyConvertedPatient
    }
}
```

You should never save changes to ParseCareKit classes directly to Parse as it may cause your data to get out-of-sync. Instead, user the `convertToCareKit` methods from each class and use the `add` or `update` methods for the CareStore. For example, the process below is recommended when creating new items to sync between CareKit and ParseCareKit

```swift
//Create doctor using CareKit
let newCareKitDoctor = OCKPatient(id: "drJohnson", givenName: "Jane", familyName: "Johnson")

//Initialize new Parse doctor with the CareKit one
_ = Doctor(careKitEntity: newCareKitDoctor){
   doctor in
   
   //Make sure the Doctor was created as Parse doctor
   guard let newParseDoctor = doctor as? Doctor else{
       return
   }
   
   //Make any edits you need to the new doctor
   newParseDoctor.type = "Cancer" //This was a custom value added in the Doctor class 
   newParseDoctor.sex = "Female" //This default from OCKPatient, Doctor has all defaults of it's CareKit counterpart
   
   
   guard let updatedCareKitDoctor = newParseDoctor.convertToCareKit(fromCloud: false) else {
       completion(nil,nil)
       return
   }
   
   store.addPatient(updatedCareKitDoctor, callbackQueue: .main){
       result in
       
       switch result{
       
       case .success(let doctor):
           print("Successfully add the doctor to the CareStore \(updatedCareKitDoctor)")
           print("CareKit and ParseCareKit will automatically handle syncing this data to the Parse Server")
       case .failure(let error):
           print("Error, couldn't save doctor. \(error)")
       }
   }
}

```

If you have a custom store, and have created your own entities, you simply need to conform to the `PCKObject` protocol which will require you to subclass `PFObject` and conform to `PFSubclassing`. You should also create methods for your custom entity such as `addToCloud,updateCloud,deleteFromCloud` and properly subclass `ParseSynchronizedStoreManager`, overiding the necessary methods. You can look through the entities like `User` and `CarePlan` as a reference for builfing your own. 
