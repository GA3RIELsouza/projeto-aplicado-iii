using System.ComponentModel.DataAnnotations;

namespace ProjetoAplicadoIII.Models
{
    public class UserModel
    {
        [Required(ErrorMessage = "O nome é obrigatório.", AllowEmptyStrings = false),
        StringLength(64, MinimumLength = 2)]
        public string Name { get; set; } = string.Empty;


        [Required(ErrorMessage = "O e-mail é obrigatório.", AllowEmptyStrings = false),
        EmailAddress(ErrorMessage = "O e-mail informado é inválido."),
        StringLength(254)]
        public string Email { get; set; } = string.Empty;


        [Required(ErrorMessage = "A senha é obrigatória.", AllowEmptyStrings = false),
        StringLength(255, MinimumLength = 8)]
        public string Password { get; set; } = string.Empty;


        [Required(ErrorMessage = "A confirmação da senha é obrigatória.", AllowEmptyStrings = false),
        Compare(nameof(Password), ErrorMessage = "As senhas informadas não coincidem.")]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
