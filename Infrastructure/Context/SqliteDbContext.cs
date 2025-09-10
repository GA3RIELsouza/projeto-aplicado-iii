using System.Runtime.ExceptionServices;
using Microsoft.EntityFrameworkCore;
using ProjetoAplicadoIII.Entities;

namespace ProjetoAplicadoIII.Infrastructure.Context
{
    public class SqliteDbContext : DbContext
    {
        public SqliteDbContext(DbContextOptions<SqliteDbContext> options) : base(options)
        {
            Database.AutoSavepointsEnabled = false;
            Database.AutoTransactionBehavior = AutoTransactionBehavior.Never;
            Database.EnsureCreated();
        }

        public DbSet<User> Users => Set<User>();

        private static Func<Task> ActionToAsyncFuncHelper(Action action) => () => { action(); return Task.CompletedTask; };

        public async Task RunInTransactionAsync(Action operations) => await RunInTransactionAsync<bool>(ActionToAsyncFuncHelper(operations), null);
        public async Task RunInTransactionAsync(Action operations, Action ifFails) => await RunInTransactionAsync(ActionToAsyncFuncHelper(operations), ifFails);
        public async Task RunInTransactionAsync<T>(Action operations, Func<T>? ifFails) => await RunInTransactionAsync(ActionToAsyncFuncHelper(operations), ifFails);

        public async Task RunInTransactionAsync(Func<Task> operations) => await RunInTransactionAsync<bool>(operations, null);
        public async Task RunInTransactionAsync(Func<Task> operations, Action ifFails) => await RunInTransactionAsync(operations, () => { ifFails(); return Task.CompletedTask; });
        public async Task RunInTransactionAsync<T>(Func<Task> operations, Func<T>? ifFails)
        {
            if (Database.CurrentTransaction is not null)
            {
                await operations();
                return;
            }

            await using var transaction = await Database.BeginTransactionAsync();

            try
            {
                await operations();
                await SaveChangesAsync();
                await transaction.CommitAsync();
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                switch (ifFails)
                {
                    case null:
                        break;

                    case Func<Task> ifFailsTask:
                        await ifFailsTask();
                        break;

                    default:
                        _ = ifFails();
                        break;
                }
                ExceptionDispatchInfo.Capture(ex).Throw();
            }
        }
    }
}
