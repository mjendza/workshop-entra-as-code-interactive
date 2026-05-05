

# Create a Microsoft Entra ID (Azure AD) group
resource "azuread_group" "workshop_users" {
  display_name       = "workshop users"
  security_enabled   = true
  assignable_to_role = true
}

# Create 25 user accounts
resource "azuread_user" "workshop_users" {
  count               = 2
  user_principal_name = "workshop.user${count.index + 1}@workshop.factorlabs.pl" # Replace with your actual domain
  display_name        = "workshop ${count.index + 1}"
  mail_nickname       = "workshop.user${count.index + 1}"
  given_name          = "workshop"
  surname             = count.index + 1

  password              = "theft-most$lunch*unpacked-1010"
  force_password_change = false # Set to true if you want users to change password on first sign-in
}

# Add all users to the group
resource "azuread_group_member" "workshop_user_memberships" {
  count            = 2
  group_object_id  = element(split("/", azuread_group.workshop_users.id), 2)
  member_object_id = element(split("/", azuread_user.workshop_users[count.index].id), 2)
}