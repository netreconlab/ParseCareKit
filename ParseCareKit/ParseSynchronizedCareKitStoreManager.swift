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
 Protocol that defines the properties and methods for parse careKit entities.
 */
public protocol PCKEntity {
    func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager)
}

public class ParseSynchronizedCareKitStoreManager: NSObject{
    
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
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var contactDictionary = [String:OCKAnyContact]()
        contacts.forEach{contactDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = Contact.query()!
        query.whereKey(kPCKContactIdKey, containedIn: Array(contactDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundContacts = objects as? [Contact] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundContacts.forEach{
                guard let contact = contactDictionary[$0.uuid] else{return}
                $0.updateCloudEventually(contact, storeManager: self.storeManager)
            }
        }
    }
    
    private func deleteCloudContacts(_ contacts: [OCKAnyContact]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var contactDictionary = [String:OCKAnyContact]()
        contacts.forEach{contactDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = Contact.query()!
        query.whereKey(kPCKContactIdKey, containedIn: Array(contactDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundContacts = objects as? [Contact] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundContacts.forEach{
                guard let contact = contactDictionary[$0.uuid] else{return}
                $0.deleteFromCloudEventually(contact, storeManager: self.storeManager)
            }
        }
    }
    
    private func addCloudContacts(_ contacts: [OCKAnyContact]) {
        contacts.forEach{
            let _ = Contact(careKitEntity: $0, storeManager: self.storeManager){
                copiedContact in
                if copiedContact != nil{
                    copiedContact!.addToCloudInBackground(self.storeManager)
                }
            }
        }
    }
    
    private func updateCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var outcomeDictionary = [String:OCKAnyOutcome]()
        outcomes.forEach{outcomeDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeCareKitIdKey, containedIn: Array(outcomeDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundOutcomes = objects as? [Outcome] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundOutcomes.forEach{
                guard let outcome = outcomeDictionary[$0.careKitId] else{return}
                $0.updateCloudEventually(outcome, storeManager: self.storeManager)
            }
        }
    }
    
    private func deleteCloudOutcomes(_ outcomes: [OCKAnyOutcome]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var outcomeDictionary = [String:OCKAnyOutcome]()
        outcomes.forEach{outcomeDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeCareKitIdKey, containedIn: Array(outcomeDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundOutcomes = objects as? [Outcome] else{
                return
            }
            //Only deleting users found in the Cloud, if they are not in the Cloud, they are ignored
            foundOutcomes.forEach{
                guard let outcome = outcomeDictionary[$0.careKitId] else{return}
                $0.deleteFromCloudEventually(outcome, storeManager: self.storeManager)
            }
        }
    }
    
    private func addCloudOutcomes(_ outcomes: [OCKAnyOutcome]) {
        outcomes.forEach{
            let _ = Outcome(careKitEntity: $0, storeManager: self.storeManager){
                copiedOutcome in
                if copiedOutcome != nil{
                    copiedOutcome!.addToCloudInBackground(self.storeManager)
                }
            }
        }
    }
    
    private func updateCloudTasks(_ tasks: [OCKAnyTask]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var taskDictionary = [String:OCKAnyTask]()
        tasks.forEach{taskDictionary[$0.id] = $0}
        
        //Setup Parse query for User table
        let query = Task.query()!
        query.whereKey(kPCKTaskIdKey, containedIn: Array(taskDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundCarePlans = objects as? [Task] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundCarePlans.forEach{
                guard let task = taskDictionary[$0.uuid] else{return}
                $0.updateCloudEventually(task, storeManager: self.storeManager)
            }
        }
    }
    
    private func deleteCloudTasks(_ tasks: [OCKAnyTask]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var taskDictionary = [String:OCKAnyTask]()
        tasks.forEach{taskDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = Task.query()!
        query.whereKey(kPCKTaskIdKey, containedIn: Array(taskDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundCarePlans = objects as? [Task] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundCarePlans.forEach{
                guard let task = taskDictionary[$0.uuid] else{return}
                $0.deleteFromCloudEventually(task, storeManager: self.storeManager)
            }
        }
    }
    
    private func addCloudTasks(_ tasks: [OCKAnyTask]) {
        tasks.forEach{
            let _ = Task(careKitEntity: $0, storeManager: self.storeManager){
                copiedTask in
                if copiedTask != nil{
                    copiedTask!.addToCloudInBackground(self.storeManager)
                }
            }
        }
    }
    
    private func updateCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var carePlanDictionary = [String:OCKAnyCarePlan]()
        carePlans.forEach{carePlanDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanIDKey, containedIn: Array(carePlanDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundCarePlans = objects as? [CarePlan] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundCarePlans.forEach{
                guard let carePlan = carePlanDictionary[$0.uuid] else{return}
                $0.updateCloudEventually(carePlan, storeManager: self.storeManager)
            }
        }
    }
    
    private func deleteCloudCarePlans(_ carePlans: [OCKAnyCarePlan]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var carePlanDictionary = [String:OCKAnyCarePlan]()
        carePlans.forEach{carePlanDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanIDKey, containedIn: Array(carePlanDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundCarePlans = objects as? [CarePlan] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundCarePlans.forEach{
                guard let carePlan = carePlanDictionary[$0.uuid] else{return}
                $0.deleteFromCloudEventually(carePlan, storeManager: self.storeManager)
            }
        }
    }
    
    private func addCloudCarePlans(_ carePlans: [OCKAnyCarePlan]) {
        carePlans.forEach{
            let _ = CarePlan(careKitEntity: $0, storeManager: self.storeManager){
                copiedCarePlan in
                if copiedCarePlan != nil{
                    copiedCarePlan!.addToCloudInBackground(self.storeManager)
                }
            }
            
        }
    }
    
    private func updateCloudPatients(_ patients: [OCKAnyPatient]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var patientsDictionary = [String:OCKAnyPatient]()
        patients.forEach{patientsDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = PFUser.query()!
        query.whereKey(kPCKUserIdKey, containedIn: Array(patientsDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundUsers = objects as? [PFUser] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundUsers.forEach{
                guard let patient = patientsDictionary[$0.uuid] else{return}
                $0.updateCloudEventually(patient, storeManager: self.storeManager)
            }
        }
        return
    }
    
    private func deleteCloudPatients(_ patients: [OCKAnyPatient]){
        //Create a dictionary of patients based on their UUID to quicky find patient later
        var patientsDictionary = [String:OCKAnyPatient]()
        patients.forEach{patientsDictionary[$0.id] = $0}
        //Setup Parse query for User table
        let query = PFUser.query()!
        query.whereKey(kPCKUserIdKey, containedIn: Array(patientsDictionary.keys))
        query.findObjectsInBackground{(objects, error) -> Void in
            guard let foundUsers = objects as? [PFUser] else{
                return
            }
            //Only updating users found in the Cloud, if they are not in the Cloud, they are ignored
            foundUsers.forEach{
                guard let patient = patientsDictionary[$0.uuid] else{return}
                $0.deleteFromCloudEventually(patient, storeManager: self.storeManager)
            }
        }
        return
    }
    
    private func addCloudPatients(_ patients: [OCKAnyPatient]) {
        patients.forEach{
            guard let thisUser = PFUser.current() else{
                return
            }
            
            //Can only add to Cloud if this patient is you
            if thisUser.uuid == $0.id{
                let _ = PFUser(careKitEntity: $0, storeManager: storeManager){
                    copiedPatient in
                    if copiedPatient != nil{
                        copiedPatient!.addToCloudInBackground(self.storeManager)
                    }
                }
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
        let query = OCKPatientQuery(for: Date())
        storeManager.store.fetchAnyPatients(query: query, callbackQueue: .main){
            result in
            
            switch result{
            case .success(let foundPatients):
                guard let patients = foundPatients as? [OCKPatient] else{return}
                let patientsToSync = patients.filter{$0.remoteID == nil}
                self.addCloudPatients(patientsToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizePatients(). \(error)")
            }
        }
    }

    public func synchronizeCarePlans(){
        let query = OCKCarePlanQuery(for: Date())
        storeManager.store.fetchAnyCarePlans(query: query, callbackQueue: .main){
            result in
            switch result{
            case .success(let foundCarePlans):
                guard let carePlans = foundCarePlans as? [OCKCarePlan] else{return}
                let carePlansToSync = carePlans.filter{$0.remoteID == nil}
                self.addCloudCarePlans(carePlansToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeCarePlans(). \(error)")
            }
        }
    }
    
    public func synchronizeTasks(){
        let query = OCKTaskQuery(for: Date())
        storeManager.store.fetchAnyTasks(query: query, callbackQueue: .main){
            result in
            switch result{
            case .success(let foundTasks):
                guard let tasks = foundTasks as? [OCKTask] else{return}
                let tasksToSync = tasks.filter{$0.remoteID == nil}
                self.addCloudTasks(tasksToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeTask(). \(error)")
            }
        }
    }
    
    public func synchronizeOutcome(){
        let query = OCKPatientQuery(for: Date())
        storeManager.store.fetchAnyPatients(query: query, callbackQueue: .main){
            result in
            switch result{
            case .success(let foundPatients):
                guard let patients = foundPatients as? [OCKPatient] else{return}
                let patientsToSync = patients.filter{$0.remoteID == nil}
                self.addCloudPatients(patientsToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizePatients(). \(error)")
            }
        }
    }
        
    public func synchronizeContacts(){
        let query = OCKContactQuery(for: Date())
        storeManager.store.fetchAnyContacts(query: query, callbackQueue: .main){
            result in
            switch result{
            case .success(let foundContacts):
                guard let contacts = foundContacts as? [OCKContact] else{return}
                let contactsToSync = contacts.filter{$0.remoteID == nil}
                self.addCloudContacts(contactsToSync)
            case .failure(let error):
                print("Error in ParseSynchronizedCareKitStoreManager.synchronizeContacts(). \(error)")
            }
        }
    }
}
