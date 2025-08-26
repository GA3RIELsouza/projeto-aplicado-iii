using ProjetoAplicadoIII.Entities;
using ProjetoAplicadoIII.Infrastructure.Context;
using ProjetoAplicadoIII.Infrastructure.Interfaces;

namespace ProjetoAplicadoIII.Infrastructure.Repositories
{
    public sealed class UserRepository(SqliteDbContext db) : RepositoryBase<User>(db), IUserRepository
    {
    }
}
