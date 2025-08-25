using ProjetoAplicadoIII.Models;

namespace ProjetoAplicadoIII.Entities
{
    public sealed class User : Entity
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public bool Active { get; set; } = true;

        public static User FromModel(UserModel model)
        {
            return new()
            {
                Id = 0,
                Email = model.Email,
                Password = model.Password,
                Name = model.Name,
                Active = true
            };
        }
    }
}
