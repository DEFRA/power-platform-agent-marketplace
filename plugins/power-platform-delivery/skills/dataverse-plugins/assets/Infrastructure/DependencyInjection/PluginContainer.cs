namespace Abc.Infrastructure.DependencyInjection
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Reflection;
    using System.Runtime.ExceptionServices;

    /// <summary>
    /// A minimal dependency injection container for plug-ins and custom workflow activities. A root holds
    /// registrations only. Each invocation creates its own execution scope, which also holds the runtime
    /// services Dataverse supplied and disposes the services it created.
    /// </summary>
    public sealed class PluginContainer : IDisposable
    {
        private readonly object gate = new object();
        private readonly Dictionary<Type, Type> registrations;
        private readonly Dictionary<Type, object> instances = new Dictionary<Type, object>();
        private readonly List<IDisposable> ownedInstances = new List<IDisposable>();
        private readonly bool executionScope;
        private bool frozen;
        private bool disposed;

        /// <summary>Initializes a new instance of the <see cref="PluginContainer"/> class as a root.</summary>
        public PluginContainer()
            : this(new Dictionary<Type, Type>(), false)
        {
        }

        private PluginContainer(Dictionary<Type, Type> registrations, bool executionScope)
        {
            this.registrations = registrations;
            this.executionScope = executionScope;
        }

        /// <summary>Registers a transient implementation of a service contract.</summary>
        /// <typeparam name="TService">The service contract.</typeparam>
        /// <typeparam name="TImplementation">The concrete implementation.</typeparam>
        public void Register<TService, TImplementation>()
            where TImplementation : TService
        {
            this.RegisterType(typeof(TService), typeof(TImplementation));
        }

        /// <summary>Registers a transient concrete service.</summary>
        /// <typeparam name="TImplementation">The concrete service type.</typeparam>
        public void Register<TImplementation>()
        {
            this.RegisterType(typeof(TImplementation), typeof(TImplementation));
        }

        /// <summary>Registers a borrowed runtime service in an execution scope. The scope never disposes it.</summary>
        /// <typeparam name="TService">The contract to expose the instance as.</typeparam>
        /// <param name="instance">The current invocation's instance.</param>
        public void Register<TService>(TService instance)
            where TService : class
        {
            if (instance == null)
            {
                throw new ArgumentNullException(nameof(instance));
            }

            lock (this.gate)
            {
                this.ThrowIfDisposed();
                if (!this.executionScope)
                {
                    throw new InvalidOperationException("Runtime instances must be registered in an execution scope.");
                }

                this.instances.Add(typeof(TService), instance);
            }
        }

        /// <summary>Freezes the root's registrations and creates a scope with a copy of them.</summary>
        /// <returns>A new execution scope, which the caller must dispose.</returns>
        public PluginContainer CreateExecutionScope()
        {
            lock (this.gate)
            {
                this.ThrowIfDisposed();
                if (this.executionScope)
                {
                    throw new InvalidOperationException("Create execution scopes from the root container only.");
                }

                this.frozen = true;
                return new PluginContainer(new Dictionary<Type, Type>(this.registrations), true);
            }
        }

        /// <summary>Builds a new object graph, using the only public constructor of each type.</summary>
        /// <typeparam name="T">The registered service contract.</typeparam>
        /// <returns>The resolved service. The container disposes any disposable services it created.</returns>
        public T Resolve<T>()
        {
            lock (this.gate)
            {
                this.ThrowIfDisposed();
                return (T)this.Resolve(typeof(T), new HashSet<Type>());
            }
        }

        /// <summary>Disposes the services this container created, newest first. Borrowed instances are left alone.</summary>
        public void Dispose()
        {
            lock (this.gate)
            {
                if (this.disposed)
                {
                    return;
                }

                this.disposed = true;
                var failures = new List<Exception>();
                for (var index = this.ownedInstances.Count - 1; index >= 0; index--)
                {
                    try
                    {
                        this.ownedInstances[index].Dispose();
                    }
                    catch (Exception exception)
                    {
                        failures.Add(exception);
                    }
                }

                this.ownedInstances.Clear();
                this.instances.Clear();
                this.registrations.Clear();
                if (failures.Count != 0)
                {
                    throw new AggregateException("Disposing container-owned services failed.", failures);
                }
            }
        }

        private void RegisterType(Type serviceType, Type implementationType)
        {
            lock (this.gate)
            {
                this.ThrowIfDisposed();
                if (this.frozen)
                {
                    throw new InvalidOperationException("Root registrations cannot change after an execution scope has been created.");
                }

                if (!implementationType.IsClass || implementationType.IsAbstract || implementationType.ContainsGenericParameters)
                {
                    throw new ArgumentException("An implementation must be a closed, concrete class.", nameof(implementationType));
                }

                this.registrations.Add(serviceType, implementationType);
            }
        }

        private object Resolve(Type serviceType, HashSet<Type> path)
        {
            object instance;
            if (this.instances.TryGetValue(serviceType, out instance))
            {
                return instance;
            }

            Type implementationType;
            if (!this.registrations.TryGetValue(serviceType, out implementationType))
            {
                throw new InvalidOperationException("No registration exists for " + serviceType.FullName + ".");
            }

            if (!path.Add(serviceType))
            {
                throw new InvalidOperationException("A circular dependency was detected for " + serviceType.FullName + ".");
            }

            try
            {
                var constructors = implementationType.GetConstructors();
                if (constructors.Length != 1)
                {
                    throw new InvalidOperationException(implementationType.FullName + " must have exactly one public constructor.");
                }

                var arguments = constructors[0].GetParameters()
                    .Select(parameter => this.Resolve(parameter.ParameterType, path))
                    .ToArray();
                try
                {
                    instance = constructors[0].Invoke(arguments);
                }
                catch (TargetInvocationException exception) when (exception.InnerException != null)
                {
                    ExceptionDispatchInfo.Capture(exception.InnerException).Throw();
                    throw;
                }

                var disposable = instance as IDisposable;
                if (disposable != null)
                {
                    this.ownedInstances.Add(disposable);
                }

                return instance;
            }
            finally
            {
                path.Remove(serviceType);
            }
        }

        private void ThrowIfDisposed()
        {
            if (this.disposed)
            {
                throw new ObjectDisposedException(nameof(PluginContainer));
            }
        }
    }
}
