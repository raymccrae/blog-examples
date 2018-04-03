import Foundation
import CoreData

extension NSPersistentStore {

    /// Determines if the store supports batch operations, currently only SQLite is supported.
    var isBatchOperationSupported: Bool {
        return type == NSSQLiteStoreType
    }

}

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
     Determines if the recieving entity is assocated with persistent stores that support
     batch operations (see NSPersistentStore.isBatchOperationSupported). Since an entity
     can be assocated with multiple persistent stores, this method will return true only
     if all persistent stores for the recieving entity support batch operations.

     - parameter coordinator: Persistent Store Coordinator
     - returns: true if batch operations are supported for the recieving entity, otherwise false.
     */
    func isBatchOperationSupported(for coordinator: NSPersistentStoreCoordinator) -> Bool {
        let stores = coordinator.persistentStores(for: self)
        guard !stores.isEmpty else {
            return false
        }
        return !stores.contains(where: { !$0.isBatchOperationSupported })
    }

    /**
     Determines if the recieving entity is assocated with persistent stores that support
     batch operations (see NSPersistentStore.isBatchOperationSupported). Since an entity
     can be assocated with multiple persistent stores, this method will return true only
     if all persistent stores for the recieving entity support batch operations.

     - parameter context: Managed Object Context
     - returns: true if batch operations are supported for the recieving entity, otherwise false.
     */
    func isBatchOperationSupported(for context: NSManagedObjectContext) -> Bool {
        guard let coordinator = context.rootPersistentStoreCoordinator else {
            return false
        }
        return isBatchOperationSupported(for: coordinator)
    }

}

extension NSManagedObjectContext {

    /**
     Fetch the root persistent store coordinator of the receiver. This method will follow the
     parent chain of managed object contexts until it finds the persistent store coordinator
     at the top level.

     - returns: The persistent store coordinator at the top level of the MOC parent chain.
     */
    var rootPersistentStoreCoordinator: NSPersistentStoreCoordinator? {
        return persistentStoreCoordinator ?? parent?.rootPersistentStoreCoordinator
    }

    /**
     Deterimes if the receiver will automatically merge changes from the store coordinator.
     This is determined by by following the chain of MOCs parents to the store coordinator
     and ensuring each MOC in the chain has automaticallyMergesChangesFromParent set to true.

     - returns: True if the receiver will automatically merge changes from the store coordinator,
                otherwise false.
     */
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

    /**
     Determines if the reciever supports batch operation.

     - parameter context: Managed Object Context.
     - returns: true if reciever supports batch operation, otherwise false.
     */
    static func isBatchOperationSupported(for context: NSManagedObjectContext) -> Bool {
        return entity().isBatchOperationSupported(for: context)
    }

    // MARK: - Delete Methods

    /**
     Deletes all managed objects that match the given predicate within the managed object
     context.

     - parameter predicate: The predicate that indicates the objects to delete.
     - parameter context: The managed object context.
     - parameter includesSubentities: If true then matching subentities will be deleted.
     - returns: An array of NSManagedObjectIDs of the object that were deleted.
     */
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

    /**
     Executes a batch delete operation (NSBatchDeleteRequest) where supported, or performs
     a conventional delete if batch operation are not supported.

     - parameter predicate: The predicate that indicates the objects to delete.
     - parameter persistentStoreCoordinator: The persistent store coordinator.
     - parameter contexts: The managed object contexts to merge delete changes to.
     - parameter includesSubentities: If true then matching subentities will be deleted.
     */
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

    // MARK:- Merge Methods

    private static func mergeBatchChanges(batchOperationSupported: Bool,
                                          key: String,
                                          objectIDs: [NSManagedObjectID],
                                          into contexts: [NSManagedObjectContext]) {
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
