//
//  ParseSynchronizedStoreManager.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKit
import Combine
import Parse

/**
 Protocol that defines the properties and methods for parse carekit entities that are synchronized using a wall clock.
 */
public protocol PCKSynchronized: PFObject, PFSubclassing {
    func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void)
    func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void)
    func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool, completion: @escaping(Bool,Error?) -> Void)
}

open class PCKEntity: PFObject {
    @NSManaged public var uuid: String
    @NSManaged public var entityId:String
    @NSManaged public var logicalClock: Int
    @NSManaged public var createdDate: Date?
    @NSManaged public var updatedDate: Date?
    @NSManaged public var userInfo: [String: String]?
    @NSManaged public var groupIdentifier: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var source: String?
    @NSManaged public var asset: String?
    @NSManaged public var notes: [Note]?
    @NSManaged public var timezoneIdentifier: String
}

open class PCKVersionedEntity: PCKEntity {
    @NSManaged public var effectiveDate: Date
    @NSManaged public var deletedDate: Date?
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    /*
    public override class func query() -> PFQuery<PFObject>? {
        <#code#>
    }*/
    
    public class func query(for date: Date) -> PFQuery<PFObject>? {
        let query = self.query()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        
        return self.query()
    }
}


open class ParseSynchronizedStoreManager: NSObject{
    
    private var storeManager: OCKSynchronizedStoreManager!
    private var cancellable:AnyCancellable!
    
    public init(_ synchronizedStore: OCKSynchronizedStoreManager, synchCareStoreDataNow: Bool=true) {
        super.init()
        
        storeManager = synchronizedStore
        cancellable = storeManager.notificationPublisher.sink { notification in

            switch notification {
            case let patientNotification as OCKPatientNotification:
                self.handlePatientNotification(patientNotification)
            case let carePlanNotification as OCKCarePlanNotification:
                self.handleCarePlanNotification(carePlanNotification)
            case let taskNotification as OCKTaskNotification:
                self.handleTaskNotification(taskNotification)
            case let outcomeNotification as OCKOutcomeNotification:
                self.handleOutcomeNotification(outcomeNotification)
            case let contactNotification as OCKContactNotification:
                self.handleContactNotification(contactNotification)
            default:
                print("Warning in ParseSynchronizedStoreManager.init(). Handling notificication \(notification) isn't implemented")
            }
        }
        if synchCareStoreDataNow{
            synchonizeAllDataToCloud()
        }
    }
    
    open func handlePatientNotification(_ notification: OCKPatientNotification) {
        switch notification.category {
        case .add: addCloudPatients([notification.patient])
        case .update: updateCloudPatients([notification.patient])
        case .delete: deleteCloudPatients([notification.patient])
        }
    }
    
    open func handleCarePlanNotification(_ notification: OCKCarePlanNotification) {
        switch notification.category {
        case .add: addCloudCarePlans([notification.carePlan])
        case .update: updateCloudCarePlans([notification.carePlan])
        case .delete: deleteCloudCarePlans([notification.carePlan])
        }
    }
    
    open func handleTaskNotification(_ notification: OCKTaskNotification) {
        switch notification.category {
        case .add: addCloudTasks([notification.task])
        case .update: updateCloudTasks([notification.task])
        case .delete: deleteCloudTasks([notification.task])
        }
    }
    
    open func handleOutcomeNotification(_ notification: OCKOutcomeNotification) {
        switch notification.category {
        case .add: addCloudOutcomes([notification.outcome])
        case .update: updateCloudOutcomes([notification.outcome])
        case .delete: deleteCloudOutcomes([notification.outcome])
        }
    }
    
    open func handleContactNotification(_ notification: OCKContactNotification) {
        switch notification.category {
        case .add: addCloudContacts([notification.contact])
        case .update: updateCloudContacts([notification.contact])
        case .delete: deleteCloudContacts([notification.contact])
        }
    }
    
    private func updateCloudContacts(_ contacts: [OCKAnyContact]){

        contacts.forEach{
            let _ = Contact(careKitEntity: $0, store: self.storeManager.store){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.updateCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func deleteCloudContacts(_ contacts: [OCKAnyContact]){
        contacts.forEach{
            let _ = Contact(careKitEntity: $0, store: self.storeManager.store){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.deleteFromCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func addCloudContacts(_ contacts: [OCKAnyContact]) {
        contacts.forEach{
            let _ = Contact(careKitEntity: $0, store: self.storeManager.store){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.addToCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func updateCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let outcome = $0
            let _ = Outcome(careKitEntity: outcome, store: storeManager.store){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.updateCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func deleteCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let careKitEntity = $0
            let _ = Outcome(careKitEntity: careKitEntity, store: self.storeManager.store){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.deleteFromCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func addCloudOutcomes(_ outcomes: [OCKAnyOutcome]) {
        outcomes.forEach{
            let _ = Outcome(careKitEntity: $0, store: self.storeManager.store){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.addToCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func updateCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0, store: self.storeManager.store){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.updateCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func deleteCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0, store: self.storeManager.store){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.deleteFromCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func addCloudTasks(_ tasks: [OCKAnyTask]) {
        tasks.forEach{
            let _ = Task(careKitEntity: $0, store: self.storeManager.store){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.addToCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func updateCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, store: self.storeManager.store){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.updateCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func deleteCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, store: self.storeManager.store){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.deleteFromCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func addCloudCarePlans(_ carePlans: [OCKAnyCarePlan]) {
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, store: self.storeManager.store){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.addToCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func updateCloudPatients(_ patients: [OCKAnyPatient]){
        
        patients.forEach{
            let _ = Patient(careKitEntity: $0, store: storeManager.store){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.updateCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func deleteCloudPatients(_ patients: [OCKAnyPatient]){
        patients.forEach{
            let _ = Patient(careKitEntity: $0, store: storeManager.store){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.deleteFromCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    private func addCloudPatients(_ patients: [OCKAnyPatient]) {
        patients.forEach{
            let _ = Patient(careKitEntity: $0, store: storeManager.store){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.addToCloud(self.storeManager.store){(_,_) in}
            }
        }
    }
    
    public func synchonizeAllDataToCloud(){
        synchronizePatients()
        synchronizeCarePlans()
        synchronizeTasks()
        synchronizeOutcome()
        synchronizeContacts()
    }
    
    public func synchronizePatients(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKPatientQuery(for: Date())
        store.fetchAnyPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let patients):
                let patientsToSync = patients.filter{$0.remoteID == nil}
                self.addCloudPatients(patientsToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedStoreManager.synchronizePatients(). \(error)")
            }
        }
    }

    public func synchronizeCarePlans(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKCarePlanQuery(for: Date())
        store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let carePlans):
                let carePlansToSync = carePlans.filter{$0.remoteID == nil}
                self.addCloudCarePlans(carePlansToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedStoreManager.synchronizeCarePlans(). \(error)")
            }
        }
    }
    
    public func synchronizeTasks(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKTaskQuery(for: Date())
        store.fetchTasks(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let tasks):
                let tasksToSync = tasks.filter{$0.remoteID == nil}
                self.addCloudTasks(tasksToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedStoreManager.synchronizeTask(). \(error)")
            }
        }
    }
    
    public func synchronizeOutcome(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKOutcomeQuery(for: Date())
        store.fetchOutcomes(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let outcomes):
                let outcomesToSync = outcomes.filter{$0.remoteID == nil}
                self.addCloudOutcomes(outcomesToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedStoreManager.synchronizeOutcomes(). \(error)")
            }
        }
    }
        
    public func synchronizeContacts(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKContactQuery(for: Date())
        store.fetchContacts(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let contacts):
                let contactsToSync = contacts.filter{$0.remoteID == nil}
                self.addCloudContacts(contactsToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedStoreManager.synchronizeContacts(). \(error)")
            }
        }
    }
}
