namespace Abc.UnitTests.Infrastructure.DependencyInjection
{
    using System;
    using System.Collections.Concurrent;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;

    [TestClass]
    public sealed class PluginContainerTests
    {
        private readonly PluginContainer root = new PluginContainer();

        private interface IDependency
        {
        }

        [TestCleanup]
        public void Cleanup()
        {
            this.root.Dispose();
        }

        [TestMethod]
        public void Resolve_RegisteredInterface_ReturnsImplementationWithInjectedDependencies()
        {
            this.root.Register<IDependency, Dependency>();
            this.root.Register<Consumer>();

            var consumer = this.root.Resolve<Consumer>();

            consumer.Dependency.Should().BeOfType<Dependency>();
        }

        [TestMethod]
        public void Resolve_CalledTwice_ReturnsNewInstanceEachTime()
        {
            this.root.Register<IDependency, Dependency>();
            this.root.Register<Consumer>();

            var first = this.root.Resolve<Consumer>();
            var second = this.root.Resolve<Consumer>();

            first.Should().NotBeSameAs(second);
            first.Dependency.Should().NotBeSameAs(second.Dependency);
        }

        [TestMethod]
        public void Resolve_UnregisteredService_ThrowsInvalidOperationException()
        {
            Action resolve = () => this.root.Resolve<Consumer>();

            resolve.Should().ThrowExactly<InvalidOperationException>().WithMessage("*" + typeof(Consumer).FullName + "*");
        }

        [TestMethod]
        public void Resolve_CircularDependency_ThrowsInvalidOperationException()
        {
            this.root.Register<Cycle>();

            Action resolve = () => this.root.Resolve<Cycle>();

            resolve.Should().ThrowExactly<InvalidOperationException>().WithMessage("*circular*");
        }

        [TestMethod]
        public void Resolve_MultiplePublicConstructors_ThrowsInvalidOperationException()
        {
            this.root.Register<Ambiguous>();

            Action resolve = () => this.root.Resolve<Ambiguous>();

            resolve.Should().ThrowExactly<InvalidOperationException>().WithMessage("*exactly one*");
        }

        [TestMethod]
        public void Resolve_NoPublicConstructor_ThrowsInvalidOperationException()
        {
            this.root.Register<NoPublicConstructor>();

            Action resolve = () => this.root.Resolve<NoPublicConstructor>();

            resolve.Should().ThrowExactly<InvalidOperationException>().WithMessage("*exactly one*");
        }

        [TestMethod]
        public void Resolve_ConstructorThrows_PropagatesOriginalException()
        {
            this.root.Register<Throwing>();

            Action resolve = () => this.root.Resolve<Throwing>();

            resolve.Should().ThrowExactly<SimulatedFailureException>().WithMessage("constructor failed");
        }

        [TestMethod]
        public void Resolve_BorrowedInstanceRegisteredInScope_ReturnsThatInstance()
        {
            var borrowed = new Dependency();
            using (var scope = this.root.CreateExecutionScope())
            {
                scope.Register<IDependency>(borrowed);

                var resolved = scope.Resolve<IDependency>();

                resolved.Should().BeSameAs(borrowed);
            }
        }

        [TestMethod]
        public void Resolve_DisposedScope_ThrowsObjectDisposedException()
        {
            var scope = this.root.CreateExecutionScope();
            scope.Dispose();

            Action resolve = () => scope.Resolve<Dependency>();

            resolve.Should().ThrowExactly<ObjectDisposedException>();
        }

        [TestMethod]
        public void Register_ImplementationIsAnInterface_ThrowsArgumentException()
        {
            Action register = () => this.root.Register<IDependency>();

            register.Should().ThrowExactly<ArgumentException>();
        }

        [TestMethod]
        public void Register_ServiceAlreadyRegistered_ThrowsArgumentException()
        {
            this.root.Register<Consumer>();

            Action register = () => this.root.Register<Consumer>();

            register.Should().ThrowExactly<ArgumentException>();
        }

        [TestMethod]
        public void Register_AfterExecutionScopeCreated_ThrowsInvalidOperationException()
        {
            using (this.root.CreateExecutionScope())
            {
                Action register = () => this.root.Register<Consumer>();

                register.Should().ThrowExactly<InvalidOperationException>();
            }
        }

        [TestMethod]
        public void Register_InstanceOnRoot_ThrowsInvalidOperationException()
        {
            Action register = () => this.root.Register<IDependency>(new Dependency());

            register.Should().ThrowExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void Register_NullInstanceInScope_ThrowsArgumentNullException()
        {
            using (var scope = this.root.CreateExecutionScope())
            {
                Action register = () => scope.Register<IDependency>(null);

                register.Should().ThrowExactly<ArgumentNullException>();
            }
        }

        [TestMethod]
        public void Register_InstanceAlreadyRegisteredInScope_ThrowsArgumentException()
        {
            using (var scope = this.root.CreateExecutionScope())
            {
                scope.Register<IDependency>(new Dependency());

                Action register = () => scope.Register<IDependency>(new Dependency());

                register.Should().ThrowExactly<ArgumentException>();
            }
        }

        [TestMethod]
        public void Register_DisposedScope_ThrowsObjectDisposedException()
        {
            var scope = this.root.CreateExecutionScope();
            scope.Dispose();

            Action register = () => scope.Register<Dependency>();

            register.Should().ThrowExactly<ObjectDisposedException>();
        }

        [TestMethod]
        public void CreateExecutionScope_FromScope_ThrowsInvalidOperationException()
        {
            using (var scope = this.root.CreateExecutionScope())
            {
                Action create = () => scope.CreateExecutionScope();

                create.Should().ThrowExactly<InvalidOperationException>();
            }
        }

        [TestMethod]
        public void CreateExecutionScope_DisposedRoot_ThrowsObjectDisposedException()
        {
            this.root.Dispose();

            Action create = () => this.root.CreateExecutionScope();

            create.Should().ThrowExactly<ObjectDisposedException>();
        }

        [TestMethod]
        public void CreateExecutionScope_ConcurrentScopes_IsolateBorrowedInstances()
        {
            const int scopeCount = 30;
            this.root.Register<Consumer>();
            var isolated = new ConcurrentBag<bool>();

            Parallel.For(0, scopeCount, index =>
            {
                using (var scope = this.root.CreateExecutionScope())
                {
                    var borrowed = new Dependency();
                    scope.Register<IDependency>(borrowed);

                    isolated.Add(ReferenceEquals(borrowed, scope.Resolve<Consumer>().Dependency));
                }
            });

            isolated.Should().HaveCount(scopeCount).And.OnlyContain(value => value);
        }

        [TestMethod]
        public void CreateExecutionScope_BorrowedInstanceInOneScope_IsNotVisibleToRoot()
        {
            this.root.Register<Consumer>();
            using (var scope = this.root.CreateExecutionScope())
            {
                scope.Register<IDependency>(new Dependency());
            }

            Action resolve = () => this.root.Resolve<Consumer>();

            resolve.Should().ThrowExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void Dispose_OwnedServices_DisposesInReverseConstructionOrder()
        {
            var log = new DisposalLog();
            this.root.Register<OwnedChild>();
            this.root.Register<OwnedParent>();
            var scope = this.root.CreateExecutionScope();
            scope.Register(log);
            scope.Resolve<OwnedParent>();

            scope.Dispose();

            log.Entries.Should().Equal("parent", "child");
        }

        [TestMethod]
        public void Dispose_CalledTwice_DisposesServicesOnce()
        {
            var log = new DisposalLog();
            this.root.Register<OwnedChild>();
            var scope = this.root.CreateExecutionScope();
            scope.Register(log);
            scope.Resolve<OwnedChild>();

            scope.Dispose();
            scope.Dispose();

            log.Entries.Should().Equal("child");
        }

        [TestMethod]
        public void Dispose_BorrowedInstance_DoesNotDisposeIt()
        {
            var borrowed = new BorrowedDisposable();
            var scope = this.root.CreateExecutionScope();
            scope.Register(borrowed);

            scope.Dispose();

            borrowed.Disposed.Should().BeFalse();
        }

        [TestMethod]
        public void Dispose_OwnedServiceFails_DisposesRemainingServicesAndThrowsAggregateException()
        {
            this.root.Register<FailingDisposable>();
            var scope = this.root.CreateExecutionScope();
            var first = scope.Resolve<FailingDisposable>();
            var second = scope.Resolve<FailingDisposable>();

            Action dispose = scope.Dispose;

            dispose.Should().ThrowExactly<AggregateException>().Which.InnerExceptions.Should().HaveCount(2);
            first.Disposed.Should().BeTrue();
            second.Disposed.Should().BeTrue();
        }

        [TestMethod]
        public void Dispose_ConstructorFailsAfterDependencyCreated_StillDisposesTheDependency()
        {
            var log = new DisposalLog();
            this.root.Register<OwnedChild>();
            this.root.Register<FailingParent>();
            var scope = this.root.CreateExecutionScope();
            scope.Register(log);
            Action resolve = () => scope.Resolve<FailingParent>();
            resolve.Should().ThrowExactly<SimulatedFailureException>();

            scope.Dispose();

            log.Entries.Should().Equal("child");
        }

        [TestMethod]
        public void Dispose_Root_DoesNotInvalidateExistingScope()
        {
            this.root.Register<Consumer>();
            using (var scope = this.root.CreateExecutionScope())
            {
                var borrowed = new Dependency();
                scope.Register<IDependency>(borrowed);

                this.root.Dispose();

                scope.Resolve<Consumer>().Dependency.Should().BeSameAs(borrowed);
            }
        }

        [TestMethod]
        public void Dispose_SiblingScope_DoesNotInvalidateOtherScope()
        {
            this.root.Register<Dependency>();
            var first = this.root.CreateExecutionScope();
            using (var second = this.root.CreateExecutionScope())
            {
                first.Dispose();

                second.Resolve<Dependency>().Should().BeOfType<Dependency>();
            }
        }

        private sealed class Dependency : IDependency
        {
        }

        private sealed class Consumer
        {
            public Consumer(IDependency dependency)
            {
                this.Dependency = dependency;
            }

            public IDependency Dependency { get; }
        }

        private sealed class Cycle
        {
            public Cycle(Cycle cycle)
            {
                this.Inner = cycle;
            }

            public Cycle Inner { get; }
        }

        private sealed class Ambiguous
        {
            public Ambiguous()
            {
            }

            public Ambiguous(IDependency dependency)
            {
                this.Dependency = dependency;
            }

            public IDependency Dependency { get; }
        }

        private sealed class NoPublicConstructor
        {
            private NoPublicConstructor()
            {
            }
        }

        private sealed class Throwing
        {
            public Throwing()
            {
                throw new SimulatedFailureException("constructor failed");
            }
        }

        private sealed class DisposalLog
        {
            private readonly List<string> entries = new List<string>();

            public IReadOnlyList<string> Entries => this.entries.ToList();

            public void Add(string entry)
            {
                this.entries.Add(entry);
            }
        }

        private sealed class OwnedChild : IDisposable
        {
            private readonly DisposalLog log;

            public OwnedChild(DisposalLog log)
            {
                this.log = log;
            }

            public void Dispose()
            {
                this.log.Add("child");
            }
        }

        private sealed class OwnedParent : IDisposable
        {
            private readonly DisposalLog log;

            public OwnedParent(OwnedChild child, DisposalLog log)
            {
                this.Child = child;
                this.log = log;
            }

            public OwnedChild Child { get; }

            public void Dispose()
            {
                this.log.Add("parent");
            }
        }

        private sealed class FailingParent
        {
            public FailingParent(OwnedChild child)
            {
                this.Child = child;
                throw new SimulatedFailureException("parent constructor failed");
            }

            public OwnedChild Child { get; }
        }

        private sealed class BorrowedDisposable : IDisposable
        {
            public bool Disposed { get; private set; }

            public void Dispose()
            {
                this.Disposed = true;
            }
        }

        private sealed class FailingDisposable : IDisposable
        {
            public bool Disposed { get; private set; }

            public void Dispose()
            {
                this.Disposed = true;
                throw new SimulatedFailureException("cleanup failed");
            }
        }
    }
}
