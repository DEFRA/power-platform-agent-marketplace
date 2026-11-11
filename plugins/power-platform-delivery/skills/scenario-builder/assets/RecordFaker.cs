using Bogus;
using Microsoft.Xrm.Sdk;

/// <summary>
/// A base <see cref="Faker{T}"/> for Dataverse early-bound entities, applying the conventions shared by every
/// record faker: an <c>en_GB</c> locale and a randomly generated <see cref="Entity.Id"/>.
/// </summary>
/// <typeparam name="TEntity">The Dataverse early-bound entity type.</typeparam>
public abstract class RecordFaker<TEntity> : Faker<TEntity>
    where TEntity : Entity, new()
{
    /// <summary>
    /// Initializes a new instance of the <see cref="RecordFaker{TEntity}"/> class.
    /// </summary>
    protected RecordFaker()
        : base("en_GB")
    {
        this.RuleFor(e => e.Id, f => f.Random.Guid());
    }
}
