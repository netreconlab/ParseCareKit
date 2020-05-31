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

open class ParseSynchronizedStoreManager: NSObject{
    
    private var storeManager: OCKSynchronizedStoreManager!
    private var cancellable:AnyCancellable!
    public var delegate: ParseRemoteSynchronizationDelegate?
    public internal(set) var customClassesToSynchronize:[String:PCKSynchronized]?
    public internal(set) var pckStoreClassesToSynchronize: [PCKStoreClass: PCKSynchronized]!
    
    public init(synchronizedStore: OCKSynchronizedStoreManager, synchCareStoreDataNow: Bool) {
        super.init()
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.getConcrete()
        self.customClassesToSynchronize = nil
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
    
    convenience public init(synchronizedStore: OCKSynchronizedStoreManager, synchCareStoreDataNow: Bool, replacePCKStoreClasses: [PCKStoreClass: PCKRemoteSynchronized]) {
        self.init(synchronizedStore: synchronizedStore, synchCareStoreDataNow: synchCareStoreDataNow)
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }
    
    convenience public init(synchronizedStore: OCKSynchronizedStoreManager, synchCareStoreDataNow: Bool, replacePCKStoreClasses: [PCKStoreClass: PCKRemoteSynchronized]?, customClasses: [String:PCKSynchronized]) {
        self.init(synchronizedStore: synchronizedStore, synchCareStoreDataNow: synchCareStoreDataNow)
        if replacePCKStoreClasses != nil{
            self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceConcreteClasses(replacePCKStoreClasses!)
        }else{
            self.pckStoreClassesToSynchronize = nil
        }
        self.customClassesToSynchronize = customClasses
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
            let _ = Contact(careKitEntity: $0){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.updateCloud(){(_,_) in}
            }
        }
    }
    
    private func deleteCloudContacts(_ contacts: [OCKAnyContact]){
        contacts.forEach{
            let _ = Contact(careKitEntity: $0){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.deleteFromCloud(){(_,_) in}
            }
        }
    }
    
    private func addCloudContacts(_ contacts: [OCKAnyContact]) {
        contacts.forEach{
            let _ = Contact(careKitEntity: $0){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.addToCloud(){(_,_) in}
            }
        }
    }
    
    private func updateCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let outcome = $0
            let _ = Outcome(careKitEntity: outcome){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.updateCloud(){(_,_) in}
            }
        }
    }
    
    private func deleteCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let careKitEntity = $0
            let _ = Outcome(careKitEntity: careKitEntity){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.deleteFromCloud(){(_,_) in}
            }
        }
    }
    
    private func addCloudOutcomes(_ outcomes: [OCKAnyOutcome]) {
        outcomes.forEach{
            let _ = Outcome(careKitEntity: $0){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.addToCloud(){(_,_) in}
            }
        }
    }
    
    private func updateCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.updateCloud(){(_,_) in}
            }
        }
    }
    
    private func deleteCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.deleteFromCloud(){(_,_) in}
            }
        }
    }
    
    private func addCloudTasks(_ tasks: [OCKAnyTask]) {
        tasks.forEach{
            let _ = Task(careKitEntity: $0){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.addToCloud(){(_,_) in}
            }
        }
    }
    
    private func updateCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.updateCloud(){(_,_) in}
            }
        }
    }
    
    private func deleteCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.deleteFromCloud(){(_,_) in}
            }
        }
    }
    
    private func addCloudCarePlans(_ carePlans: [OCKAnyCarePlan]) {
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.addToCloud(){(_,_) in}
            }
        }
    }
    
    private func updateCloudPatients(_ patients: [OCKAnyPatient]){
        
        patients.forEach{
            let _ = Patient(careKitEntity: $0){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.updateCloud(){(_,_) in}
            }
        }
    }
    
    private func deleteCloudPatients(_ patients: [OCKAnyPatient]){
        patients.forEach{
            let _ = Patient(careKitEntity: $0){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.deleteFromCloud(){(_,_) in}
            }
        }
    }
    
    private func addCloudPatients(_ patients: [OCKAnyPatient]) {
        patients.forEach{
            let _ = Patient(careKitEntity: $0){
                copiedPatient in
                guard let patient = copiedPatient as? Patient else{return}
                patient.addToCloud(){(_,_) in}
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
