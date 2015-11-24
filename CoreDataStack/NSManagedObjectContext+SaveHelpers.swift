//
//  NSManagedObjectContext+Extensions.swift
//  CoreDataSMS
//
//  Created by Robert Edwards on 2/23/15.
//  Copyright (c) 2015 Big Nerd Ranch. All rights reserved.
//

import CoreData

public typealias CoreDataStackSaveCompletion = CoreDataStack.SaveResult -> Void

/**
 Convenience extension to `NSManagedObjectContext` that ensures that saves to contexts of type
 `MainQueueConcurrencyType` and `PrivateQueueConcurrencyType` are dispatched on the correct GCD queue.
*/
public extension NSManagedObjectContext {

    /**
    Convenience method to synchronously save the `NSManagedObjectContext` if changes are present.
    Method also ensures that the save is executed on the correct queue when using Main/Private queue concurrency types.
     
     - throws: Errros produced by the `save()` function on the `NSManagedObjectContext`
    */
    public func saveContextAndWait() throws {
        var saveError: ErrorType?
        switch concurrencyType {
        case .ConfinementConcurrencyType:
            try sharedSaveFlow()
        case .MainQueueConcurrencyType,
             .PrivateQueueConcurrencyType:
            self.performBlockAndWait {
                do {
                    try self.sharedSaveFlow()
                } catch let error {
                    saveError = error
                }
            }
        }

        if let saveError = saveError {
            throw saveError
        }
    }

    /**
    Convenience method to asynchronously save the `NSManagedObjectContext` if changes are present.
    Method also ensures that the save is executed on the correct queue when using Main/Private queue concurrency types.

    - parameter completion: Completion closure with a `SaveResult` to be executed upon the completion of the save operation.
    */
    public func saveContext(completion: CoreDataStackSaveCompletion? = nil) {
        let saveFlow: (CoreDataStackSaveCompletion?) -> () = { completion in
            do {
                try self.sharedSaveFlow()
                completion?(.Success)
            } catch let saveError {
                completion?(.Failure(saveError))
            }
        }

        switch concurrencyType {
        case .ConfinementConcurrencyType:
            saveFlow(completion)
        case .PrivateQueueConcurrencyType,
        .MainQueueConcurrencyType:
            self.performBlock {
                saveFlow(completion)
            }
        }
    }

    private func sharedSaveFlow() throws {
        if hasChanges {
            do {
                try save()
            } catch let error {
                throw error
            }
        }
    }
}
