export interface UserRegisterDTO {
  firstName: string
  lastName: string
  email: string
  password: string
}

export interface User {
  firstName: string
  lastName: string
  email: string
  password: string
  roles: string[]
}