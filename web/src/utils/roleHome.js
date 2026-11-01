export function roleHome(role) {
  switch (role) {
    case "STUDENT":
      return "/student";
    case "TEACHER":
      return "/teacher";
    case "COORDINATOR":
      return "/coordinator";
    case "ADMIN":
      return "/admin";
    default:
      return "/login";
  }
}
