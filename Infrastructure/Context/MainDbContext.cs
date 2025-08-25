using System.Runtime.ExceptionServices;
using Microsoft.EntityFrameworkCore;
using ProjetoAplicadoIII.Entities;

namespace ProjetoAplicadoIII.Infrastructure.Context
{
    public class MainDbContext : DbContext
    {
        public MainDbContext(DbContextOptions<MainDbContext> options) : base(options)
        {
            Database.AutoSavepointsEnabled = false;
            Database.AutoTransactionBehavior = AutoTransactionBehavior.Never;
            Database.EnsureCreated();
        }

        public DbSet<User> Users => Set<User>();

        public async Task RunInTransactionAsync(Func<Task> operations, Func<Task>? ifFails = null)
        {
            if (this.Database.CurrentTransaction is not null)
            {
                await operations();
                return;
            }

            await this.Database.OpenConnectionAsync();
            await using var transaction = await this.Database.BeginTransactionAsync();

            try
            {
                await operations();
                await this.SaveChangesAsync();
                await transaction.CommitAsync();
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                if (ifFails is not null) await ifFails();
                ExceptionDispatchInfo.Capture(ex).Throw();
            }
            finally
            {
                await this.Database.CloseConnectionAsync();
            }
        }
    }
}
