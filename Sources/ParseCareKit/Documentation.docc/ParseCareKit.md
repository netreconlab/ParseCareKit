# ``ParseCareKit``

Seamlessly Synchronize CareKit 2.1+ data with a Parse Server.

## Overview

This framework provides an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.1+ data with [parse-server](https://github.com/parse-community/parse-server) using [Parse-Swift](https://github.com/netreconlab/Parse-Swift). The learn more about how to use ParseCareKit check out the [API documentation](https://netreconlab.github.io/ParseCareKit/api/) along with the rest of the README.

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

For the backend, it is suggested to use [parse-hipaa](https://github.com/netreconlab/parse-hipaa) which is an out-of-the-box HIPAA compliant Parse/[Postgres](https://www.postgresql.org) or Parse/[Mongo](https://www.mongodb.com) server that comes with [Parse Dashboard](https://github.com/parse-community/parse-dashboard). Since [parse-hipaa](https://github.com/netreconlab/parse-hipaa) is a pare-server, it can be used for [iOS](https://docs.parseplatform.org/ios/guide/), [Android](https://docs.parseplatform.org/android/guide/), and web based apps. API's such as [GraphQL](https://docs.parseplatform.org/graphql/guide/), [REST](https://docs.parseplatform.org/rest/guide/), and [JS](https://docs.parseplatform.org/js/guide/) are also enabled in parse-hipaa and can be accessed directly or tested via the "API Console" in parse-dashboard. See the [Parse SDK documentation](https://parseplatform.org/#sdks) for details. These docker images include the necessary database auditing and logging for HIPAA compliance.

You can also use ParseCareKit with any parse-server setup. If you devide to use your own parse-server, it's strongly recommended to add the following [CloudCode](https://github.com/netreconlab/parse-hipaa/tree/main/parse/cloud) to your server's "cloud" folder to ensure the necessary classes and fields are created as well as ensuring uniqueness of pushed entities. In addition, you should follow the [directions](https://github.com/netreconlab/parse-hipaa#running-in-production-for-parsecarekit) to setup additional indexes for optimized queries. ***Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance.***

The following CareKit Entities are synchronized with Parse tables/classes:
- [x] OCKPatient <-> Patient
- [x] OCKCarePlan <-> CarePlan
- [x] OCKTask <-> Task
- [x] OCKHealthKitTask <-> HealthKitTask
- [x] OCKContact <-> Contact
- [x] OCKOutcome <-> Outcome
- [x] OCKRevisionRecord.Clock <-> Clock

ParseCareKit enables iOS and watchOS devices belonging to the same user to be reactively sychronized using [ParseLiveQuery](https://docs.parseplatform.org/parse-server/guide/#live-queries) without the need of push notifications assuming the [LiveQuery server has been configured](https://docs.parseplatform.org/parse-server/guide/#livequery-server). 

## Topics

### Initialize the SDK

- ``ParseCareKit/ParseRemote/init(uuid:auto:subscribeToServerUpdates:defaultACL:)``
- ``ParseCareKit/ParseRemote/init(uuid:auto:replacePCKStoreClasses:subscribeToServerUpdates:defaultACL:)``
- ``ParseCareKit/ParseRemote/init(uuid:auto:replacePCKStoreClasses:customClasses:subscribeToServerUpdates:defaultACL:)``
