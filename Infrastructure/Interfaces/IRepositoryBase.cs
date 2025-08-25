using ProjetoAplicadoIII.Entities;

namespace ProjetoAplicadoIII.Infrastructure.Interfaces
{
    public interface IRepositoryBase<TEntity> : IDisposable, IAsyncDisposable where TEntity : Entity
    {
        Task AddAsync(TEntity entity);
        Task AddRangeAsync(params TEntity[] entities);
        ValueTask<TEntity?> FindAsync(long id);
        void Update(TEntity entity);
        void UpdateRange(params TEntity[] entities);
        void Remove(TEntity entity);
        void RemoveRange(params TEntity[] entities);
    }
}
