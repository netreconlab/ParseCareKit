# ParseCareKit
![CareKitImage](https://user-images.githubusercontent.com/8621344/234047811-de85e2d6-3c5a-405d-bd0e-a94ce603c8e3.png)

---

[![Documentation](https://img.shields.io/badge/read_-docs-2196f3.svg)](https://swiftpackageindex.com/netreconlab/ParseCareKit/documentation)
[![Tuturiol](https://img.shields.io/badge/read_-tuturials-2196f3.svg)](https://netreconlab.github.io/ParseCareKit/release/tutorials/parsecarekit/)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnetreconlab%2FParseCareKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/netreconlab/ParseCareKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnetreconlab%2FParseCareKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/netreconlab/ParseCareKit)
![Xcode 13.3+](https://img.shields.io/badge/xcode-13.3%2B-blue.svg)
[![ci](https://github.com/netreconlab/ParseCareKit/actions/workflows/ci.yml/badge.svg)](https://github.com/netreconlab/ParseCareKit/actions/workflows/ci.yml)
[![release](https://github.com/netreconlab/ParseCareKit/actions/workflows/release.yml/badge.svg)](https://github.com/netreconlab/ParseCareKit/actions/workflows/release.yml)
[![Coverage](https://codecov.io/gh/netreconlab/ParseCareKit/branch/main/graph/badge.svg)](https://app.codecov.io/gh/netreconlab/ParseCareKit/branch/main)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/netreconlab/ParseCareKit/#license)

---

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) data with [parse-server](https://github.com/parse-community/parse-server) using [Parse-Swift](https://github.com/netreconlab/Parse-Swift). The learn more about how to use ParseCareKit check out the [API documentation](https://swiftpackageindex.com/netreconlab/ParseCareKit/documentation/) along with the rest of the README.

For the backend, it is suggested to use [parse-hipaa](https://github.com/netreconlab/parse-hipaa) which is an out-of-the-box HIPAA compliant Parse/[Postgres](https://www.postgresql.org) or Parse/[Mongo](https://www.mongodb.com) server that comes with [Parse Dashboard](https://github.com/parse-community/parse-dashboard). Since [parse-hipaa](https://github.com/netreconlab/parse-hipaa) is a pare-server, it can be used for [iOS](https://docs.parseplatform.org/ios/guide/), [Android](https://docs.parseplatform.org/android/guide/), and web based apps. API's such as [GraphQL](https://docs.parseplatform.org/graphql/guide/), [REST](https://docs.parseplatform.org/rest/guide/), and [JS](https://docs.parseplatform.org/js/guide/) can also be enabled in parse-hipaa to enable building apps with other languages. See the [Parse SDK documentation](https://parseplatform.org/#sdks) for details. The parse-hipaa docker images include the necessary database auditing and logging for HIPAA compliance.

You can also use ParseCareKit with any parse-server setup. If you devide to use your own parse-server, it's strongly recommended to add the following [CloudCode](https://github.com/netreconlab/parse-hipaa/tree/main/parse/cloud) to your server's "cloud" folder to ensure the necessary classes and fields are created as well as ensuring uniqueness of pushed entities. In addition, you should follow the [directions](https://github.com/netreconlab/parse-hipaa#running-in-production-for-parsecarekit) to setup additional indexes for optimized queries. ***Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance.***

The following CareKit Entities are synchronized with Parse tables/classes:
- [x] OCKPatient <-> Patient
- [x] OCKCarePlan <-> CarePlan
- [x] OCKContact <-> Contact
- [x] OCKTask <-> Task
- [x] OCKHealthKitTask <-> HealthKitTask
- [x] OCKOutcome <-> Outcome
- [x] OCKRevisionRecord <-> RevisionRecord

ParseCareKit enables iOS, watchOS, macOS devices belonging to the same user to be reactively sychronized using [ParseLiveQuery](https://docs.parseplatform.org/parse-server/guide/#live-queries) without the need of push notifications assuming the [LiveQuery server has been configured](https://docs.parseplatform.org/parse-server/guide/#livequery-server). 

## CareKit Sample App with ParseCareKit
A sample app, [CareKitSample-ParseCareKit](https://github.com/netreconlab/CareKitSample-ParseCareKit), connects to the aforementioned [parse-hipaa](https://github.com/netreconlab/parse-hipaa) and demonstrates how CareKit data can be easily synched to the Cloud using ParseCareKit.

<img src="https://github.com/netreconlab/CareKitSample-ParseCareKit/assets/8621344/d60d194a-87a5-41e9-8ae4-41a847e91ea3" width="300"> <img src="https://github.com/netreconlab/CareKitSample-ParseCareKit/assets/8621344/ca0ac2e0-d17d-4bae-88fd-f59b94812419" width="300">

### ParseCareKit.plist with server connection information
ParseCareKit comes with a helper method, [PCKUtility.configureParse()](https://github.com/netreconlab/ParseCareKit/blob/4912bf7677511d148b52d03146c31cc428a83454/ParseCareKit/PCKUtility.swift#L14) that easily helps apps connect to your parse-server. To leverage the helper method, copy the [ParseCareKit.plist](https://github.com/netreconlab/CareKitSample-ParseCareKit/blob/main/OCKSample/Supporting%20Files/ParseCareKit.plist) file your "Supporting Files" folder in your Xcode project. Be sure to change `ApplicationID` and `Server` to the correct values for your server. Simply add the following inside `didFinishLaunchingWithOptions` in `AppDelegate.swift`:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

//Pulls from ParseCareKit.plist to connect to server
PCKUtility.configureParse() 

//If you need certificate pinning:
PCKUtility.configureParse { (challenge, completionHandler) in
    //Return how you want to handle the challenge. See docs for more information.
    completionHandler(.performDefaultHandling, nil)
}
```

## What version of ParseCareKit Suits Your Needs?
- (Most cases) Need to use ParseCareKit for iOS14+, watchOS7+, and/or macOS 13+ and will be using the latest (the minimal required commit is from [PR #508](https://github.com/carekit-apple/CareKit/commit/248c42c4e4ea97ff5fe349361fa6e0a849eab204)) [CareKit 2.1+](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore`) within your app? You should use the [main](https://github.com/netreconlab/ParseCareKit) branch. You can take advantage of all of the capabilities of ParseCareKit. You should use `ParseRemote()` see [below](#synchronizing-your-data) more details. This branch uses the [Parse-Swift SDK](https://github.com/netreconlab/Parse-Swift) instead of the [Parse-Objc SDK](https://github.com/parse-community/Parse-SDK-iOS-OSX).
- Need to use ParseCareKit for iOS13+ and/or watchOS6+ and will be using the latest [CareKit](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (but you would like to use the [Parse Objc SDK](https://github.com/parse-community/Parse-SDK-iOS-OSX)) within your app? You will need to use Cocoapods and the [Parse-Objc SDK](https://github.com/netreconlab/ParseCareKit/tree/parse-objc) branch. You can still use all of the capabilities of ParseCareKit. You should use `ParseSynchronizedStoreManager()` see [here](https://github.com/netreconlab/ParseCareKit/tree/parse-objc#synchronizing-your-data) for more details.
- Need to use ParseCareKit for iOS13+ and will be using [CareKit <= 2.0.1](https://github.com/carekit-apple/CareKit#carekit-), [CareKitUI <= 2.0.1](https://github.com/carekit-apple/CareKit#carekitui-), and [CareKitStore <= 2.0.1](https://github.com/carekit-apple/CareKit#carekitstore-) (using `OCKStore` or conforming to `OCKAnyStoreProtocol`) within your app? You should use the [carekit_2.0.1](https://github.com/netreconlab/ParseCareKit/tree/carekit_2.0.1) branch. You can still use most of the capabilities of ParseCareKit, but you will be limited to syncing via a "wall clock" instead of "knowledge vectors". You will also have to use the [Parse Objc SDK](https://github.com/parse-community/Parse-SDK-iOS-OSX)) and Cocoapods. You should use `ParseSynchronizedStoreManager()` see [here](https://github.com/netreconlab/ParseCareKit/tree/carekit_2.0.1#synchronizing-your-data) for more details.

**Note that it is recommended to use Vector Clocks (`ParseRemote`) over Wall Clocks (`ParseSynchronizedStoreManager`) as the latter can run into more synching issues. If you choose to go the wall clock route, I recommend having your application suited for 1 device per user to reduce potential synching issues. You can learn more about how vector clocks work by looking at [vector clocks](https://sookocheff.com/post/time/vector-clocks/).**

## Install ParseCareKit

### Swift Package Manager (SPM)
ParseCareKit can be installed via SPM. Open an existing project or create a new Xcode project and navigate to `File > Swift Packages > Add Package Dependency`. Enter the url `https://github.com/netreconlab/ParseCareKit` and tap `Next`. Choose the main branch, and on the next screen, check off the package.

Note: ParseCareKit includes [CareKitStore](https://github.com/carekit-apple/CareKit#carekitstore-) (it's a dependency) from CareKit's main branch, so there's no need to add CareKitStore to your app. If you want the rest of CareKit, you only need to add [CareKit](https://github.com/carekit-apple/CareKit#carekit-) and [CareKitUI](https://github.com/carekit-apple/CareKit#carekitui-) via SPM. Anytime you need ParseCareKit, simply add `import ParseCareKit` at the top of the file.

### Installing via cocoapods
To install via cocoapods, go to the [Parse-Objc SDK](https://github.com/netreconlab/ParseCareKit/tree/parse-objc#installing-via-cocoapods) branch for the readme. The main branch is not compatable with cocoapods as the CareKit framework is not compatible with Cocoapods.


### Installing as a framework
- Fork the project
- Build the project
- In your project Targets, click your corresponding target and then click the `General` heading to the right
- Place `ParseCareKit.framework` in `Frameworks, Libraries, and Embedded Content` and it should automatically appear in `Linked Binary with Libraries` under the `Build Phases` section
- Then, simply place `import ParseCareKit` at the top of any file that needs the framework.

**If you have CareKit already in your project via SPM or copied, you will need to remove it as ParseCareKit comes with the a compatibile version of CareKit and a conflict of CareKit appearing twice will cause your app to crash**

## Setup Parse Server Remote
For details on how to setup parse-server, follow the directions [here](https://github.com/parse-community/parse-server#getting-started) or look at their detailed [guide](https://docs.parseplatform.org/parse-server/guide/). Note that standard deployment locally on compouter, docker, AWS, Google Cloud, is not HIPAA complaint by default. 

### Protecting Patients data in the Cloud using ACL's
`ParseCareKit` will set a default ACL on every object saved to your Parse Server with read/write access only for the user who created the data. If you want different level of access by default, you should pass the default ACL you prefer while initializing `ParseCareKit`. For example, to make all data created to only be read and written by the user who created it, do the following:

```swift
//Set default ACL for all Parse Classes
var newACL = ParseACL()
newACL.publicRead = false
newACL.publicWrite = false        
newACL.setReadAccess(user: user, value: true)
newACL.setWriteAccess(user: user, value: true)
do {
    let parse = try ParseRemote(uuid: UUID(uuidString: "3B5FD9DA-C278-4582-90DC-101C08E7FC98")!,
                                auto: false,
                                subscribeToRemoteUpdates: false,
                                defaultACL: newACL)
} catch {
    print(error.localizedDescription)
}
```

When giving access to a CareTeam or other entities, special care should be taken when deciding the propper ACL or Role. Feel free to read more about [ACLs](https://docs.parseplatform.org/ios/guide/#security-for-user-objects) and [Role](https://docs.parseplatform.org/ios/guide/#roles) access in Parse. For details, your setup should look similar to the code [here](https://github.com/netreconlab/CareKitSample-ParseCareKit/blob/a4b1106816f37d227ad9a6ea3e84e02556ccbbc8/OCKSample/AppDelegate.swift#L53).

## Synchronizing Your Data
Assuming you are already familiar with [CareKit](https://github.com/carekit-apple/CareKit) (look at their documentation for details). Using ParseCareKit is simple, especially if you are using `OCKStore` out-of-the-box. If you are using a custom `OCKStore` you will need to subclass and write some additional code to synchronize your care-store with parse-server.

### Using vector clocks aka CareKit's KnowledgeVector (`ParseRemote`)

ParseCareKit stays synchronized with the `OCKStore` by leveraging `OCKRemoteSynchronizable`.  I recommend having this as a singleton, as it can handle all syncs from the carestore. An example is below:

```swift
/*Use Clock and OCKRemoteSynchronizable to keep data synced. 
This works with 1 or many devices per patient.*/
let uuid = UUID(uuidString: "3B5FD9DA-C278-4582-90DC-101C08E7FC98")!
let remoteStoreManager = ParseRemote(uuid: uuid, auto: true)
let dataStore = OCKStore(name: "myDataStore", type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self //Conform to this protocol if you are writing custom CloudCode in Parse and want to push syncs
remoteStoreManager.parseRemoteDelegate = self //Conform to this protocol to resolve conflicts
```

The `uuid` being passed to `ParseRemote` is used for the Clock. A possibile solution that allows for high flexibity is to have 1 of these per user-type per user. This allows you to have have one `ParseUser` that can be a "Doctor" and a "Patient". You should generate a different uuid for this particular ParseUser's `Doctor` and `PCKPatient` type. You can save all types to ParseUser:

```swift
let userTypeUUIDDictionary = [
"doctor": UUID().uuidString,
"patient": UUID().uuidString
]

//Store the possible uuids for each type
guard var user = User.current else {
    return
}
user.userTypes = userTypeUUIDDictionary //Note that you need to save the UUID in string form to Parse
user.loggedInType = "doctor" 
user.save()

//Start synch with the correct knowlege vector for the particular type of user
let lastLoggedInType = User.current?.loggedInType
let userTypeUUIDString = User.current?.userTypes[lastLoggedInType] as! String
let userTypeUUID = UUID(uuidString: userTypeUUID)!

//Start synching 
let remoteStoreManager = ParseRemote(uuid: userTypeUUID, auto: true)
let dataStore = OCKStore(name: "myDataStore", type: .onDisk, remote: remoteStoreManager)
remoteStoreManager.delegate = self //Conform to this protocol if you are writing custom CloudCode in Parse and want to push syncs
remoteStoreManager.parseRemoteDelegate = self //Conform to this protocol to resolve conflicts
```

Register as a delegate just in case ParseCareKit needs your application to update a CareKit entity. ParseCareKit doesn't have access to your CareKitStor, so your app will have to make the necessary update if ParseCareKit detects a problem and needs to make an update locally. Registering for the delegates also allows you to handle synching conflicts. An example is below:


```swift
extension AppDelegate: OCKRemoteSynchronizationDelegate, ParseRemoteDelegate {
    func didRequestSynchronization(_ remote: OCKRemoteSynchronizable) {
        print("Implement so ParseCareKit can tell your OCKStore to sync to the cloud")
        //example
        store.synchronize { error in
            print(error?.localizedDescription ?? "Successful sync with remote!")
        }
    }
    
    func remote(_ remote: OCKRemoteSynchronizable, didUpdateProgress progress: Double) {
        print("Completed: \(progress)")
    }

    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        let conflictPolicy = OCKMergeConflictResolutionPolicy.keepDevice
        completion(conflictPolicy)
    }

    func successfullyPushedDataToCloud(){        
             print("Notified when data is succefully pushed to the cloud")        
         }
    }

```

## Customizing Parse Entities to Sync with CareKit

There will be times you need to customize entities by adding fields that are different from the standard CareKit entity fields. If the fields you want to add can be converted to strings, it is recommended to take advantage of the `userInfo: [String:String]` field of a CareKit entity. To do this, you simply extend the entity you want customize using `extension`. For example, below shows how to add fields to OCKPatient<->Patient:

```swift
extension Patient: Person {
    var primaryCondition String? {
        guard let userInfo = userInfo else {
            return nil
        }
        return userInfo["CustomPatientUserInfoPrimaryConditionKey"]
    }

    mutating func setPrimaryCondition(_ primaryCondition: String?) {
        var mutableUserInfo = currentUserInfo()

        if let primaryCondition = primaryCondition {
            mutableUserInfo[PatientUserInfoKey.primaryCondition.rawValue] = primaryCondition
        }else{
            mutableUserInfo.removeValue(forKey: PatientUserInfoKey.primaryCondition.rawValue)
        }
        userInfo = mutableUserInfo
    }
}
```

If you want to make you own types and use them to replace the concrete CareKit ones. You should copy/paste the respective code from ParseCareKit, e.g. `PCKPatient`, `PCKContact`, `PCKTask`, etc. Then you need to pass your custom struct when initializing `ParseRemoteSynchronizingManager`. The way to do this is below:

```swift
let updatedConcreteClasses: [PCKStoreClass: PCKSynchronizable] = [
    .patient: CancerPatient()
]

remoteStoreManager = ParseRemote(uuid: uuid, auto: true, replacePCKStoreClasses: updatedConcreteClasses)
dataStore = OCKStore(name: storeName, type: .onDisk(), remote: remoteStoreManager)
remoteStoreManager.delegate = self
remoteStoreManager.parseRemoteDelegate = self
```


Of course, you can customize further by implementing your copyCareKit and converToCareKit methods and not call the super methods.


You can also map "custom" `Parse` classes to concrete `OCKStore` classes. This is useful when you want to have `Doctor`'s and `PCKPatient`'s in the same app, but would like to map them both locally to the `OCKPatient` table on iOS devices.  ParseCareKit makes this simple. Follow the same process as creating `CancerPatient` above, but add the `kPCKCustomClassKey` key to `userInfo` with `Doctor.className()` as the value. See below:

```swift
struct Doctor: Patient {
    public var type:String?
    
    func new(from careKitEntity: OCKEntity)->PCKSynchronizable? {
        
        switch careKitEntity {
        case .patient(let entity):
            return Doctor(careKitEntity: entity)
        default:
            os_log("new(with:) The wrong type (%{private}@) of entity was passed", log: .carePlan, type: .error, careKitEntity.entityType.debugDescription)
            completion(nil)
        }
    }
    
    //Add a convienience initializer to to ensure that that the doctor class is always created correctly
    init(careKitEntity: OCKAnyPatient {
        self.init()
        self.new(from: careKitEntity)
        self.userInfo = [kPCKCustomClassKey: self.className]
    }
    
    copyCareKit(_ patientAny: OCKAnyPatient)->Patient? {
        
        guard let doctor = patientAny as? OCKPatient else{
            return nil
        }
        
        super.new(from: doctor, clone: clone)
        self.type = cancerPatient.userInfo?["CustomDoctorUserInfoTypeKey"]
        return seld
    }
    
    func convertToCareKit() -> OCKPatient? {
        guard var partiallyConvertedDoctor = super.convertToCareKit() else{return nil}
        
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

***You should never save changes to ParseCareKit classes directly to Parse as it may cause your data to get out-of-sync.*** Instead, user the `convertToCareKit` methods from each class and use the `add` or `update` methods from the CareStore. For example, the process below is recommended when creating new items to sync between CareKit and ParseCareKit

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
   
   
   guard let updatedCareKitDoctor = newParseDoctor.convertToCareKit() else {
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

### Querying Parse Like OCKQuery in CareKit
There are some of helper methods provided in ParseCareKit to query parse in a similar way you would query in CareKit. This is important because `PCKPatient`, `PCKCarePlan`, `PCKContact`, and `PCKTask` are versioned entities and `PCKOutcome`'s are tombstoned. Querying each of the aforementioned classes with a reugular query will return all versions for "versioned" entities or tombstoned and not tombstoned `PCKOutcome`s. A description of how versioning works in CareKit can be found [here](https://github.com/carekit-apple/CareKit#carekitstore-).

```swift
//To query the most recent version
let query = Patient.query(for: Date())

query.find(callbackQueue: .main){ results in
            
    switch results {

    case .success(let patients):
        print(patients)
    case .failure(let error):
        print(error)
    }
}
```

For `PCKOutcome`:

```swift
//To query all current outcomes
let query = Outcome.queryNotDeleted()
query.find(callbackQueue: .main){ results in

    switch results {

    case .success(let outcomes):
        print(outcomes)
    case .failure(let error):
        print(error)
    }
}

```

### Custom OCKStores

If you have a custom store, and have created your own entities, you simply need to conform to  `PCKVersionable` (OCKPatient, OCKCarePlan, OCKTask, OCKContact, OCKOutcome) protocols. In addition you will need to conform to `PCKSynchronizable`. You can look through ParseCareKit entities such as `PCKCarePlan`(`PCKVersionable`) as a reference for building your own. 
