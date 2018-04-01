//: Playground - noun: a place where people can play

import UIKit
import CoreData

var str = "Hello, playground"

extension NSManagedObjectModel {

    /**
     Get all configurations that the given entity is associated with.

     - parameter entity: The entity description whos configurations to lookup.
     - returns: An array of configurations that are associated to the entity.
     */
    func configurations(for entity: NSEntityDescription) -> [String] {
        return configurations.filter { (configuration) -> Bool in
            let entitiesForConfig = entities(forConfigurationName: configuration)
            return entitiesForConfig?.contains(entity) ?? false
        }
    }

}

extension NSPersistentStore {

    /// Determines if the store supports batch operations, currently only SQLite is support.
    var isBatchOperationSupported: Bool {
        return self.type == NSSQLiteStoreType
    }

}

extension NSPersistentStoreCoordinator {

    /**
     Get an array of persistent stores that persist the given entity. While this
     is typically one store, in advanced configurations an entity can be stored
     in multiple stores.

     - parameter entity: The entity whos store we should lookup.
     - returns: An array of stores that persist the entity.
     */
    func persistentStores(for entity: NSEntityDescription) -> [NSPersistentStore] {
        let configurationsForEntity = managedObjectModel.configurations(for: entity)
        return persistentStores.filter { (store) -> Bool in
            return configurationsForEntity.contains(store.configurationName)
        }
    }

}

extension NSEntityDescription {

    /**
     Determines if the recieving
     */
    func isBatchOperationSupported(for coordinator: NSPersistentStoreCoordinator) -> Bool {
        let stores = coordinator.persistentStores(for: self)
        guard !stores.isEmpty else {
            return false
        }
        return !stores.contains(where: { !$0.isBatchOperationSupported })
    }

    func isBatchOperationSupported(for context: NSManagedObjectContext) -> Bool {
        guard let coordinator = context.persistentStoreCoordinator else {
            return false
        }
        return isBatchOperationSupported(for: coordinator)
    }

}

extension NSManagedObjectContext {

    var automaticallyMergesChangesFromStoreCoordinator: Bool {
        if !automaticallyMergesChangesFromParent {
            return false
        } else {
            if let _ = persistentStoreCoordinator { // if this mocs parent is the store coordinator
                return true
            } else if let parentMOC = parent {
                return parentMOC.automaticallyMergesChangesFromStoreCoordinator
            } else {
                return false
            }
        }
    }

    /**
     Wraps the regular perform method, but allows the block to throw. Error are propogated back to the caller.
     */
    func perform(_ block: @escaping () throws -> Swift.Void) throws {
        var blockError: Error? = nil
        perform {
            do {
                try block()
            } catch {
                blockError = error
            }
        }

        if let error = blockError {
            throw error
        }
    }

}

extension NSManagedObject {

    static func isBatchOperationSupported(for context: NSManagedObjectContext) -> Bool {
        return entity().isBatchOperationSupported(for: context)
    }

    // MARK: - Delete Methods

    @discardableResult
    static func delete(where predicate: NSPredicate?,
                       into context: NSManagedObjectContext,
                       includesSubentities: Bool = true) throws -> [NSManagedObjectID] {
        let fetchRequest = NSFetchRequest<NSManagedObject>()
        fetchRequest.entity = entity()
        fetchRequest.predicate = predicate
        fetchRequest.includesSubentities = includesSubentities

        var objectIDs: [NSManagedObjectID] = []
        let result = try context.fetch(fetchRequest)
        for object in result {
            objectIDs.append(object.objectID)
            context.delete(object)
        }
        return objectIDs
    }

    static func batchDelete(where predicate: NSPredicate?,
                            on persistentStoreCoordinator: NSPersistentStoreCoordinator,
                            into contexts: [NSManagedObjectContext],
                            includesSubentities: Bool = true) throws {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        let batchOperationSupported = isBatchOperationSupported(for: context)

        var deletedObjectIDs: [NSManagedObjectID] = []
        if batchOperationSupported {
            try context.perform {
                deletedObjectIDs = try executeBatchDelete(where: predicate,
                                                          into: context,
                                                          includesSubentities: includesSubentities)
            }
        } else { // else batch delete is not supported, fall back to regular delete
            try context.perform {
                deletedObjectIDs = try delete(where: predicate,
                                              into: context,
                                              includesSubentities: includesSubentities)
                try context.save()
            }
        }

        // Merge changes to other contexts.
        mergeBatchChanges(batchOperationSupported: batchOperationSupported,
                          key: NSDeletedObjectsKey,
                          objectIDs: deletedObjectIDs,
                          into: contexts)
    }

    private static func executeBatchDelete(where predicate: NSPredicate?,
                                           into context: NSManagedObjectContext,
                                           includesSubentities: Bool) throws -> [NSManagedObjectID] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = entity()
        fetchRequest.predicate = predicate
        fetchRequest.includesSubentities = includesSubentities

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try context.execute(deleteRequest)
        guard let deleteResult = result as? NSBatchDeleteResult,
              let objectIDs = deleteResult.result as? [NSManagedObjectID] else {
            return []
        }
        return objectIDs
    }

    // MARK: - Update Methods

    @discardableResult
    static func update(set keyedValues: [String: Any],
                       where predicate: NSPredicate?,
                       into context: NSManagedObjectContext,
                       includesSubentities: Bool = true) throws -> [NSManagedObjectID] {
        let fetchRequest = NSFetchRequest<NSManagedObject>()
        fetchRequest.entity = entity()
        fetchRequest.predicate = predicate
        fetchRequest.includesSubentities = includesSubentities

        var objectIDs: [NSManagedObjectID] = []
        let result = try context.fetch(fetchRequest)
        for object in result {
            objectIDs.append(object.objectID)
            object.setValuesForKeys(keyedValues)
        }
        return objectIDs
    }

    static func batchUpdate(set keyedValues: [String: Any],
                            where predicate: NSPredicate?,
                            on persistentStoreCoordinator: NSPersistentStoreCoordinator,
                            into contexts: [NSManagedObjectContext],
                            includesSubentities: Bool = true) throws {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        let batchOperationSupported = isBatchOperationSupported(for: context)

        var updatedObjectIDs: [NSManagedObjectID] = []
        if batchOperationSupported {
            try context.perform {
                updatedObjectIDs = try executeBatchUpdate(set: keyedValues,
                                                          where: predicate,
                                                          into: context,
                                                          includesSubentities: includesSubentities)
            }
        } else { // else batch delete is not supported, fall back to regular delete
            try context.perform {
                updatedObjectIDs = try update(set: keyedValues,
                                              where: predicate,
                                              into: context,
                                              includesSubentities: includesSubentities)
                try context.save()
            }
        }

        // Merge changes to other contexts.
        mergeBatchChanges(batchOperationSupported: batchOperationSupported,
                          key: NSUpdatedObjectsKey,
                          objectIDs: updatedObjectIDs,
                          into: contexts)
    }

    private static func executeBatchUpdate(set keyedValues: [String: Any],
                                           where predicate: NSPredicate?,
                                           into context: NSManagedObjectContext,
                                           includesSubentities: Bool) throws -> [NSManagedObjectID] {
        let updateRequest = NSBatchUpdateRequest(entity: entity())
        updateRequest.resultType = .updatedObjectIDsResultType
        updateRequest.propertiesToUpdate = keyedValues
        updateRequest.predicate = predicate
        updateRequest.includesSubentities = includesSubentities

        let result = try context.execute(updateRequest)
        guard let updateResult = result as? NSBatchUpdateResult,
            let objectIDs = updateResult.result as? [NSManagedObjectID] else {
                return []
        }
        return objectIDs
    }

    private static func mergeBatchChanges(batchOperationSupported: Bool, key: String, objectIDs: [NSManagedObjectID], into contexts: [NSManagedObjectContext]) {
        guard !objectIDs.isEmpty else {
            return
        }
        let changes =  [key: objectIDs]
        let mergeToContexts: [NSManagedObjectContext]
        if batchOperationSupported {
            mergeToContexts = contexts
        } else { // if we did not use a batch request then we can filter out the mocs that will auto update
            mergeToContexts = contexts.filter { !$0.automaticallyMergesChangesFromStoreCoordinator }
        }
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: mergeToContexts)
    }

}
