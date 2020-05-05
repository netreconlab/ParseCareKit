//
//  ParseSynchronizedCareKitStoreManager.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Foundation
import CareKit
import Combine
import Parse

/**
 Protocol that defines the properties and methods for parse carekit entities.
 */
public protocol PCKEntity: PFObject, PFSubclassing {
    func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager)
    func updateCloudEventually(_ storeManager: OCKSynchronizedStoreManager)
    func deleteFromCloudEventually(_ storeManager: OCKSynchronizedStoreManager)
}

open class ParseSynchronizedCareKitStoreManager: NSObject{
    
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
                print("Warning in ParseSynchronizedCareKitStoreManager.init(). Handling notificication \(notification) isn't implemented")
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
            let _ = Contact(careKitEntity: $0, storeManager: self.storeManager){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.updateCloudEventually(self.storeManager)
            }
        }
    }
    
    private func deleteCloudContacts(_ contacts: [OCKAnyContact]){
        contacts.forEach{
            let _ = Contact(careKitEntity: $0, storeManager: self.storeManager){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.deleteFromCloudEventually(self.storeManager)
            }
        }
    }
    
    private func addCloudContacts(_ contacts: [OCKAnyContact]) {
        contacts.forEach{
            let _ = Contact(careKitEntity: $0, storeManager: self.storeManager){
                copiedContact in
                guard let contact = copiedContact as? Contact else{return}
                contact.addToCloudInBackground(self.storeManager)
            }
        }
    }
    
    private func updateCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let outcome = $0
            let _ = Outcome(careKitEntity: outcome, storeManager: storeManager){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.updateCloudEventually(self.storeManager)
            }
        }
    }
    
    private func deleteCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        outcomes.forEach{
            let _ = Outcome(careKitEntity: $0, storeManager: self.storeManager){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.deleteFromCloudEventually(self.storeManager)
            }
        }
    }
    
    private func addCloudOutcomes(_ outcomes: [OCKAnyOutcome]) {
        outcomes.forEach{
            let _ = Outcome(careKitEntity: $0, storeManager: self.storeManager){
                copiedOutcome in
                guard let outcome = copiedOutcome as? Outcome else{return}
                outcome.addToCloudInBackground(self.storeManager)
            }
        }
    }
    
    private func updateCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0, storeManager: self.storeManager){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.updateCloudEventually(self.storeManager)
            }
        }
    }
    
    private func deleteCloudTasks(_ tasks: [OCKAnyTask]){
        tasks.forEach{
            let _ = Task(careKitEntity: $0, storeManager: self.storeManager){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.deleteFromCloudEventually(self.storeManager)
            }
        }
    }
    
    private func addCloudTasks(_ tasks: [OCKAnyTask]) {
        tasks.forEach{
            let _ = Task(careKitEntity: $0, storeManager: self.storeManager){
                copiedTask in
                guard let task = copiedTask as? Task else{return}
                task.addToCloudInBackground(self.storeManager)
            }
        }
    }
    
    private func updateCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, storeManager: self.storeManager){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.updateCloudEventually(self.storeManager)
            }
        }
    }
    
    private func deleteCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, storeManager: self.storeManager){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.deleteFromCloudEventually(self.storeManager)
            }
        }
    }
    
    private func addCloudCarePlans(_ carePlans: [OCKAnyCarePlan]) {
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, storeManager: self.storeManager){
                copiedCarePlan in
                guard let carePlan = copiedCarePlan as? CarePlan else{return}
                carePlan.addToCloudInBackground(self.storeManager)
            }
        }
    }
    
    private func updateCloudPatients(_ patients: [OCKAnyPatient]){
        
        patients.forEach{
            let _ = User(careKitEntity: $0, storeManager: storeManager){
                copiedPatient in
                guard let patient = copiedPatient as? User else{return}
                patient.updateCloudEventually(self.storeManager)
            }
        }
    }
    
    private func deleteCloudPatients(_ patients: [OCKAnyPatient]){
        patients.forEach{
            let _ = User(careKitEntity: $0, storeManager: storeManager){
                copiedPatient in
                guard let patient = copiedPatient as? User else{return}
                patient.deleteFromCloudEventually(self.storeManager)
            }
        }
    }
    
    private func addCloudPatients(_ patients: [OCKAnyPatient]) {
        patients.forEach{
            let _ = User(careKitEntity: $0, storeManager: storeManager){
                copiedPatient in
                guard let patient = copiedPatient as? User else{return}
                patient.addToCloudInBackground(self.storeManager)
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
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizePatients(). \(error)")
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
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeCarePlans(). \(error)")
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
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeTask(). \(error)")
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
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeOutcomes(). \(error)")
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
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeContacts(). \(error)")
            }
        }
    }
    
    public func patchAddUUIDsToOutcomes(){
        guard let store = storeManager.store as? OCKStore else{return}
        let query = OCKOutcomeQuery()
        store.fetchOutcomes(query: query, callbackQueue: .global(qos: .background)){
            results in
            switch results{
                
            case .success(let outcomes):
                outcomes.forEach{
                    var outcomeUpdated = false
                    var mutableOutcome = $0
                    if mutableOutcome.userInfo == nil{
                        let uuid = UUID.init().uuidString
                        mutableOutcome.userInfo = [kPCKOutcomeUserInfoIDKey: uuid]
                        if mutableOutcome.tags == nil{
                            mutableOutcome.tags = [uuid]
                        }else{
                            mutableOutcome.tags!.append(uuid)
                        }
                        outcomeUpdated = true
                    }else if mutableOutcome.userInfo![kPCKOutcomeUserInfoIDKey] == nil{
                        let uuid = UUID.init().uuidString
                        mutableOutcome.userInfo![kPCKOutcomeUserInfoIDKey] = uuid
                        if mutableOutcome.tags == nil{
                            mutableOutcome.tags = [uuid]
                        }else{
                            mutableOutcome.tags!.append(uuid)
                        }
                        outcomeUpdated = true
                    }
                    
                    for (index,value) in mutableOutcome.values.enumerated(){
                        var mutableValue = value
                        if mutableValue.userInfo == nil{
                            let uuid = UUID.init().uuidString
                            mutableValue.userInfo = [kPCKOutcomeValueUserInfoIDKey: uuid]
                            if mutableValue.tags == nil{
                                mutableValue.tags = [uuid]
                            }else{
                                mutableValue.tags!.append(uuid)
                            }
                            mutableOutcome.values[index] = mutableValue
                            outcomeUpdated = true
                        }else if mutableValue.userInfo![kPCKOutcomeValueUserInfoIDKey] == nil{
                            let uuid = UUID.init().uuidString
                            mutableValue.userInfo![kPCKOutcomeValueUserInfoIDKey] = uuid
                            if mutableValue.tags == nil{
                                mutableValue.tags = [uuid]
                            }else{
                                mutableValue.tags!.append(uuid)
                            }
                            mutableOutcome.values[index] = mutableValue
                            outcomeUpdated = true
                        }
                    }
                    
                    if outcomeUpdated{
                        store.updateOutcome(mutableOutcome, callbackQueue: .global(qos: .background)){
                            results in
                            switch results{
                                
                            case .success(let outcome):
                                print("ParseSynchronizedCareKitStoreManager.patchAddUUIDsToOutcomes() added UUID to \(outcome)")
                            case .failure(let error):
                                print("Error saving updated outcome in ParseSynchronizedCareKitStoreManager.patchAddUUIDsToOutcomes(). \(error)")
                            }
                        }
                    }
                    
                }
            case .failure(let error):
                print("Error fetching outcomes in ParseSynchronizedCareKitStoreManager.patchAddUUIDsToOutcomes(). \(error)")
            }
        }
        
    }
}
