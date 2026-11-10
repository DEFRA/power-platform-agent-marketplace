namespace Abc.Dataverse
{
    using System;
    using Microsoft.Xrm.Sdk;

    /// <summary>
    /// Hand-written helpers for copying entities and working out which values changed. They live outside the
    /// generated model's namespace so that regenerating the model can't overwrite them.
    /// </summary>
    public static class EntityExtensions
    {
        /// <summary>
        /// Creates a shallow copy of the entity. The attribute collection is new, so adding or replacing values never
        /// changes the source. Attribute values are shared, so replace mutable values rather than changing them.
        /// </summary>
        /// <typeparam name="T">The entity type.</typeparam>
        /// <param name="entity">The entity to copy.</param>
        /// <returns>A new entity with the same identifier and attribute values.</returns>
        public static T Clone<T>(this T entity)
            where T : Entity, new()
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            var clone = new T();
            foreach (var attribute in entity.Attributes)
            {
                clone[attribute.Key] = attribute.Value;
            }

            // A parameterless Entity has no logical name, and setting an empty identifier on an early-bound type
            // would add a primary key attribute that the source doesn't have.
            clone.LogicalName = entity.LogicalName;
            if (clone.Id != entity.Id)
            {
                clone.Id = entity.Id;
            }

            return clone;
        }

        /// <summary>
        /// Gets an entity holding only the values that are new or different, ready for an Update request. Values are
        /// compared with <see cref="object.Equals(object, object)"/>.
        /// </summary>
        /// <param name="updated">The entity holding the values you want.</param>
        /// <param name="original">The entity to compare against.</param>
        /// <returns>A new entity holding only the new or different values.</returns>
        public static Entity GetChanges(this Entity updated, Entity original)
        {
            if (updated == null)
            {
                throw new ArgumentNullException(nameof(updated));
            }

            if (original == null)
            {
                throw new ArgumentNullException(nameof(original));
            }

            var changes = new Entity(updated.LogicalName, updated.Id);
            foreach (var attribute in updated.Attributes)
            {
                object value;
                if (!original.Attributes.TryGetValue(attribute.Key, out value)
                    || !Equals(value, attribute.Value))
                {
                    changes[attribute.Key] = attribute.Value;
                }
            }

            return changes;
        }
    }
}
