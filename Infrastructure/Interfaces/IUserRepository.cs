using ProjetoAplicadoIII.Entities;

namespace ProjetoAplicadoIII.Infrastructure.Interfaces
{
    public interface IUserRepository : IRepositoryBase<User>
    {
        Task<List<User>> ListUsersAsync();
    }
}
