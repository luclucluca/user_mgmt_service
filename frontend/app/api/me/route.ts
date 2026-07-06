import { cookies } from "next/headers"

export async function GET() {
  const token = (await cookies()).get("jwt")?.value

  if (!token) {
    return Response.json({ error: "Unauthorized" }, { status: 401 })
  }

  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/users/me`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  if (!res.ok) {
    return Response.json({ error: "Failed to fetch user" }, { status: res.status })
  }

  const data = await res.json()

  return Response.json(data)
}