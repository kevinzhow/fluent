import CodableKit
import Async
import Foundation

/// Has create and update timestamps.
public protocol SoftDeletable: Model, AnySoftDeletable {
    /// Key referencing deleted at property.
    typealias DeletedAtKey = WritableKeyPath<Self, Date?>

    /// The date at which this model was deleted.
    /// nil if the model has not been deleted yet.
    /// If this property is true, the model will not
    /// be included in any query results unless
    /// `.withSoftDeleted()` is used.
    static var deletedAtKey: DeletedAtKey { get }
}

extension SoftDeletable {
    /// Fluent deleted at property.
    public var fluentDeletedAt: Date? {
        get { return self[keyPath: Self.deletedAtKey] }
        set { self[keyPath: Self.deletedAtKey] = newValue }
    }
}

// MARK: Model

extension Model where Self: SoftDeletable, Database: QuerySupporting, ID: KeyStringDecodable {
    /// Permanently deletes a soft deletable model.
    public func forceDelete(on conn: DatabaseConnectable) -> Future<Self> {
        return query(on: conn)._delete(self)
    }

    /// Restores a soft deleted model.
    public func restore(on connection: DatabaseConnectable) -> Future<Self> {
        var copy = self
        copy.fluentDeletedAt = nil
        return query(on: connection).withSoftDeleted().update(copy)
    }
}

// MARK: Query

extension DatabaseQuery {
    /// If true, soft deleted models should be included.
    internal var withSoftDeleted: Bool {
        get { return extend["withSoftDeleted"] as? Bool ?? false }
        set { extend["withSoftDeleted"] = newValue }
    }
}

extension QueryBuilder where Model: SoftDeletable {
    /// Includes soft deleted models in the results.
    public func withSoftDeleted() -> Self {
        query.withSoftDeleted = true
        return self
    }
}

/// Unfortunately we need this hack until we have existentials.
/// note: do not rely on this exterally.
public protocol AnySoftDeletable: AnyModel {
    /// Pointer to type erased key string
    static var deletedAtField: QueryField { get }

    /// Access the deleted at property.
    var fluentDeletedAt: Date? { get set }
}

extension SoftDeletable {
    /// See `AnySoftDeletable.deletedAtField`
    public static var deletedAtField: QueryField {
        return QueryField(
            entity: entity,
            name: Self.codingPath(forKey: deletedAtKey)[0].stringValue
        )
    }
}
