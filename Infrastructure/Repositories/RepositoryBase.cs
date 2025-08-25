using Microsoft.EntityFrameworkCore;
using ProjetoAplicadoIII.Entities;
using ProjetoAplicadoIII.Infrastructure.Context;
using ProjetoAplicadoIII.Infrastructure.Interfaces;

namespace ProjetoAplicadoIII.Infrastructure.Repositories
{
    public abstract class RepositoryBase<TEntity>(MainDbContext db) : IRepositoryBase<TEntity> where TEntity : Entity
    {
        private protected readonly MainDbContext _db = db;
        private protected readonly DbSet<TEntity> _set = db.Set<TEntity>();

        private bool _disposed = false;

        public async Task AddAsync(TEntity entity) => await _set.AddAsync(entity);
        public async Task AddRangeAsync(params TEntity[] entities) => await _set.AddRangeAsync(entities);
        public async ValueTask<TEntity?> FindAsync(long id) => await _set.FindAsync(id);
        public void Remove(TEntity entity) => _set.Remove(entity);
        public void RemoveRange(params TEntity[] entities) => _set.RemoveRange(entities);
        public void Update(TEntity entity) => _set.Update(entity);
        public void UpdateRange(params TEntity[] entities) => _set.UpdateRange(entities);

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (_disposed)
            {
                return;
            }

            if (disposing)
            {
                _db.Dispose();
            }

            _disposed = true;
        }

        public async ValueTask DisposeAsync()
        {
            if (_disposed)
            {
                return;
            }

            await _db.DisposeAsync();

            _disposed = true;

            GC.SuppressFinalize(this);
        }
    }
}
