using System.ComponentModel.DataAnnotations;

namespace ProjetoAplicadoIII.Models
{
    public class UserModel
    {
        [Required, StringLength(64, MinimumLength = 2)]
        public string Name { get; set; } = string.Empty;


        [Required, EmailAddress, StringLength(254)]
        public string Email { get; set; } = string.Empty;


        [Required, StringLength(255, MinimumLength = 8)]
        public string Password { get; set; } = string.Empty;


        [Required, Compare(nameof(Password))]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
