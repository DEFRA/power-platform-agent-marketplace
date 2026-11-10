namespace Abc.UnitTests.Dataverse
{
    using System;
    using Abc.Dataverse;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Client;

    [TestClass]
    public sealed class EntityExtensionsTests
    {
        private readonly Guid id = Guid.NewGuid();

        [TestMethod]
        public void Clone_NullEntity_ThrowsArgumentNullException()
        {
            Action clone = () => ((GeneratedCase)null).Clone();

            clone.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Clone_Entity_ReturnsDifferentInstanceOfTheSameType()
        {
            var original = new Entity("account", this.id);

            var clone = original.Clone();

            clone.Should().NotBeSameAs(original);
            clone.Should().BeOfType<Entity>();
            clone.LogicalName.Should().Be(original.LogicalName);
            clone.Id.Should().Be(this.id);
        }

        [TestMethod]
        public void Clone_TypedEntity_ReturnsTheSameEarlyBoundType()
        {
            var original = new GeneratedCase { Id = this.id, Name = "Name" };

            var clone = original.Clone();

            clone.Should().NotBeSameAs(original);
            clone.Should().BeOfType<GeneratedCase>();
            clone.Id.Should().Be(this.id);
            clone.CaseId.Should().Be(this.id);
            clone.Name.Should().Be("Name");
        }

        [TestMethod]
        public void Clone_AttributeAddedToClone_DoesNotChangeTheOriginal()
        {
            var original = new Entity("account", this.id) { ["name"] = "Original" };

            var clone = original.Clone();
            clone["name"] = "Changed";
            clone["extra"] = 1;

            original["name"].Should().Be("Original");
            original.Contains("extra").Should().BeFalse();
        }

        [TestMethod]
        public void Clone_Entity_IsShallowSoAttributeValuesAreShared()
        {
            var reference = new EntityReference("contact", Guid.NewGuid());
            var original = new Entity("account", this.id) { ["primarycontactid"] = reference };

            var clone = original.Clone();

            clone["primarycontactid"].Should().BeSameAs(reference);
        }

        [TestMethod]
        public void Clone_TypedEntityWithoutAnIdentifier_DoesNotAddAnIdentifierAttribute()
        {
            var original = new GeneratedCase { Name = "Name" };

            var clone = original.Clone();

            clone.Attributes.Count.Should().Be(original.Attributes.Count);
            clone.Contains(GeneratedCase.PrimaryIdAttribute).Should().BeFalse();
        }

        [TestMethod]
        public void GetChanges_NullUpdated_ThrowsArgumentNullException()
        {
            var entity = new Entity("account");

            Action getChanges = () => ((Entity)null).GetChanges(entity);

            getChanges.Should().ThrowExactly<ArgumentNullException>().WithParameterName("updated");
        }

        [TestMethod]
        public void GetChanges_NullOriginal_ThrowsArgumentNullException()
        {
            var entity = new Entity("account");

            Action getChanges = () => entity.GetChanges(null);

            getChanges.Should().ThrowExactly<ArgumentNullException>().WithParameterName("original");
        }

        [TestMethod]
        public void GetChanges_NothingChanged_ReturnsEntityWithNoAttributes()
        {
            var original = new Entity("account", this.id) { ["name"] = "Name" };

            var changes = original.Clone().GetChanges(original);

            changes.Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_ChangedAndNewValues_ReturnsOnlyThoseValues()
        {
            var original = new Entity("account", this.id) { ["name"] = "Name", ["telephone1"] = "0123" };
            var updated = original.Clone();
            updated["name"] = "Changed";
            updated["fax"] = "0456";

            var changes = updated.GetChanges(original);

            changes.Attributes.Should().HaveCount(2);
            changes["name"].Should().Be("Changed");
            changes["fax"].Should().Be("0456");
        }

        [TestMethod]
        public void GetChanges_Entity_KeepsTheLogicalNameAndIdentifier()
        {
            var original = new Entity("account", this.id);
            var updated = original.Clone();
            updated["name"] = "Changed";

            var changes = updated.GetChanges(original);

            changes.LogicalName.Should().Be("account");
            changes.Id.Should().Be(this.id);
        }

        [TestMethod]
        public void GetChanges_ValueRemovedFromUpdated_IsNotReported()
        {
            var original = new Entity("account", this.id) { ["name"] = "Name" };
            var updated = new Entity("account", this.id);

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_NullReplacedByValue_IsReportedAsAChange()
        {
            var original = new Entity("account", this.id) { ["name"] = null };
            var updated = original.Clone();
            updated["name"] = "Name";

            updated.GetChanges(original)["name"].Should().Be("Name");
        }

        [TestMethod]
        public void GetChanges_StringsWithTheSameText_AreNotChanges()
        {
            var original = new Entity("account", this.id) { ["name"] = new string("Name".ToCharArray()) };
            var updated = new Entity("account", this.id) { ["name"] = new string("Name".ToCharArray()) };

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_StringsDifferingInCase_AreChanges()
        {
            var original = new Entity("account", this.id) { ["name"] = "name" };
            var updated = new Entity("account", this.id) { ["name"] = "Name" };

            updated.GetChanges(original)["name"].Should().Be("Name");
        }

        [TestMethod]
        public void GetChanges_DifferentEntityReferenceInstancesForTheSameRecord_AreNotChanges()
        {
            var contactId = Guid.NewGuid();
            var original = new Entity("account", this.id) { ["primarycontactid"] = new EntityReference("contact", contactId) };
            var updated = new Entity("account", this.id) { ["primarycontactid"] = new EntityReference("contact", contactId) };

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_EntityReferenceToADifferentRecord_IsAChange()
        {
            var original = new Entity("account", this.id) { ["primarycontactid"] = new EntityReference("contact", Guid.NewGuid()) };
            var updated = new Entity("account", this.id) { ["primarycontactid"] = new EntityReference("contact", Guid.NewGuid()) };

            updated.GetChanges(original).Attributes.Keys.Should().Contain("primarycontactid");
        }

        [TestMethod]
        public void GetChanges_MoneyWithTheSameAmount_IsNotAChange()
        {
            var original = new Entity("account", this.id) { ["revenue"] = new Money(10m) };
            var updated = new Entity("account", this.id) { ["revenue"] = new Money(10m) };

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_MoneyWithADifferentAmount_IsAChange()
        {
            var original = new Entity("account", this.id) { ["revenue"] = new Money(10m) };
            var updated = new Entity("account", this.id) { ["revenue"] = new Money(11m) };

            updated.GetChanges(original).Attributes.Keys.Should().Contain("revenue");
        }

        [TestMethod]
        public void GetChanges_OptionSetValueWithTheSameValue_IsNotAChange()
        {
            var original = new Entity("account", this.id) { ["industrycode"] = new OptionSetValue(1) };
            var updated = new Entity("account", this.id) { ["industrycode"] = new OptionSetValue(1) };

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_OptionSetValueWithADifferentValue_IsAChange()
        {
            var original = new Entity("account", this.id) { ["industrycode"] = new OptionSetValue(1) };
            var updated = new Entity("account", this.id) { ["industrycode"] = new OptionSetValue(2) };

            updated.GetChanges(original).Attributes.Keys.Should().Contain("industrycode");
        }

        [TestMethod]
        public void GetChanges_DateTimeWithTheSameValue_IsNotAChange()
        {
            var original = new Entity("account", this.id) { ["lastusedincampaign"] = new DateTime(2026, 1, 2, 3, 4, 5, DateTimeKind.Utc) };
            var updated = new Entity("account", this.id) { ["lastusedincampaign"] = new DateTime(2026, 1, 2, 3, 4, 5, DateTimeKind.Utc) };

            updated.GetChanges(original).Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetChanges_DateTimeWithADifferentValue_IsAChange()
        {
            var original = new Entity("account", this.id) { ["lastusedincampaign"] = new DateTime(2026, 1, 2, 3, 4, 5, DateTimeKind.Utc) };
            var updated = new Entity("account", this.id) { ["lastusedincampaign"] = new DateTime(2026, 1, 2, 3, 4, 6, DateTimeKind.Utc) };

            updated.GetChanges(original).Attributes.Keys.Should().Contain("lastusedincampaign");
        }

        // A minimal stand-in for an early-bound class from the model builder. As in generated code, setting the
        // primary key property also sets base.Id, and setting Id writes the primary key attribute.
        [EntityLogicalName("abc_case")]
        private sealed class GeneratedCase : Entity
        {
            public const string PrimaryIdAttribute = "abc_caseid";
            public const string NameAttribute = "abc_name";

            public GeneratedCase()
                : base("abc_case")
            {
            }

            [AttributeLogicalName(PrimaryIdAttribute)]
            public Guid? CaseId
            {
                get
                {
                    return this.GetAttributeValue<Guid?>(PrimaryIdAttribute);
                }

                set
                {
                    this.SetAttributeValue(PrimaryIdAttribute, value);
                    base.Id = value ?? Guid.Empty;
                }
            }

            [AttributeLogicalName(PrimaryIdAttribute)]
            public override Guid Id
            {
                get
                {
                    return base.Id;
                }

                set
                {
                    this.CaseId = value;
                }
            }

            [AttributeLogicalName(NameAttribute)]
            public string Name
            {
                get
                {
                    return this.GetAttributeValue<string>(NameAttribute);
                }

                set
                {
                    this.SetAttributeValue(NameAttribute, value);
                }
            }
        }
    }
}
