import { NextResponse } from "next/server"

export async function POST(req: Request) {
  try {
    const body = await req.json()

    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/users/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    })

    if (!res.ok) {
      return NextResponse.json(
          { message: "Invalid credentials" },
          { status: 401 }
      )
    }

    const authHeader = res.headers.get("authorization")

    const token = authHeader?.replace("Bearer ", "")

    if (!token) {
      return NextResponse.json({ error: "No token" }, { status: 500 })
    }

    const response = NextResponse.json({ success: true })

    response.cookies.set("jwt", token, {
      httpOnly: true,
      sameSite: "lax",
      secure: false,
      path: "/",
      maxAge: 60 * 60 * 24 * 7
    })

    return response
  } catch (err) {
    return NextResponse.json(
        { message: "Server error" },
        { status: 500 }
    )
  }
}