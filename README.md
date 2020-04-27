# ParseCareKit
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/netreconlab/ParseCareKit/#license) ![Swift](https://img.shields.io/badge/swift-5.0-brightgreen.svg) ![Xcode 11.0+](https://img.shields.io/badge/Xcode-11.0%2B-blue.svg) ![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue.svg)

**Use at your own risk. There is not promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

This framework contains an API to synchronize CareKit 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance. Look at hipaa-mongo and [hipaa_mongo](https://github.com/netreconlab/hipaa_mongodb) and [hipaa-postges]()(will post soon) to get started with HIPAA compliant databases that can be configured with pare-server. An example of how to use parse-server with [postgres](https://www.postgresql.org) and [parse-dashboard](https://github.com/parse-community/parse-dashboard) can be found at [parse-postgres](https://github.com/netreconlab/parse-postgres). 

**This framework is mixed with Parse (cocoapods) and CareKit 2.0+ (SPM). Due to the compatibility of cocoapods and SPM, I've only managed to get this working as a standalone framework (you will have to clone, build, and copy the framework to your projects "Frameworks, Libraries, and Embedded Content" section. I haven't figured out (nor know if it's possible) to deploy a in cocoapods or SPM**

# Install ParseCareKit
- Fork the project
- Build the project
- In your project Targets, click your corresponding target and then click the `General` heading to the right
- Place `ParseCareKit.framework` in `Frameworks, Libraries, and Embedded Content` and it should automatically appear in `Linked Binary with Libraries` under the `Build Phases` section
- Then, simply place `import ParseCareKit` at the top of any file that needs the framework.

**If you have CareKit already in your project via SPM or copied, you will need to remove it as ParseCareKit comes with the latest CareKit from the master branch and the conflict of CareKit appearing twice will cause your app to crash**

# Installing ParseSDK-iOS-MacOS
Follow the [guide](https://docs.parseplatform.org/ios/guide/) for directions on installing the iOS SDK. It should be straight forward with cocoapods. 

# Setup Parse Server
For details on how to setup parse-server, follow the directions [here](https://github.com/parse-community/parse-server#getting-started) or look at their detailed [guide](https://docs.parseplatform.org/parse-server/guide/). Note that standard deployment locally on compouter, docker, AWS, Google Cloud, isn't HIPAA complaint by default. 

# Synchronizing Your Data
Assuming you are already familiar with [CareKit](https://github.com/carekit-apple/CareKit) (look at their documentation for details). Using ParseCareKit is simple, especially if you are using `OCKStore` out-of-the-box. If you are using a custom `OCKStore` you will need to subclass and write some additional code to synchronize your care-store with parse-server.

ParseCareKit stays synchronized with the `OCKStore` by leveraging `OCKSynchronizedStoreManager`. Once your care-store is setup, simply pass an instance of `OCKSynchronizedStoreManager` to [ParseSynchronizedCareKitStoreManager](https://github.com/netreconlab/ParseCareKit/blob/master/ParseCareKit/ParseSynchronizedCareKitStoreManager.swift). I recommend having this as a singleton, as it can handle all syncs from the carestore from here. An example is below:

```
let dataStore = OCKStore(name: "myDataStore", type: .onDisk)
let dataStoreManager = OCKSynchronizedStoreManager(wrapping: dataStore)
let cloudStoreManager = ParseSynchronizedCareKitStoreManager(dataStoreManager)
```

During initialization of `ParseSynchronizedCareKitStoreManager`, all CareKit data that has `remoteID == nil` will automatically be synced to your parse-server, once synced, the `remoteID` for each entity will be replaced by the corresponding `objectId` on your parse-server.

** Note that only the latest state of an OCK entity is synchronized to parse-server. The parse-server doesn't maintain the versioned data like the local OCKStore. If you want this functionality, you will have to develop it as the framework doesn't support it, and parse-server queries are not setup for this. **

The mapping from CareKit -> Parse tables/classes are as follows:
* OCKPatient <-> User
* OCKCarePlan <-> CarePlan
* OCKTask <-> Task
* OCKContact <-> Contact
* OCKOutcome <-> Outcome
* OCKOutcomeValue <-> OutcomeValue
* OCKScheduleElement <-> ScheduleElement
* OCKNote <-> Note

To create a Parse object from a CareKit object:

```
let newPatient = OCKPatient(id: "uniqueId", givenName: "Alice", familyName: "Johnson")
let parseObject = PFUser(careKitEntity: newPatient, storeManager: dataStoreManager){
    copiedParse in
                    
                    guard let parseUserObject = copiedParse else{
                        print("Error copying OCKPatient")
                        return
                    }
                }
```

To create a CareKit object from a Parse object:
```
guard let careKitObject = newPatient.convertToCareKit() else{
  print("Error converting to CareKit object")
  return
}
```

If you have a custom store, there are a few files/methods you will want to override. Look at the "open" methods in the following [files](https://github.com/netreconlab/ParseCareKit/tree/master/ParseCareKit).
