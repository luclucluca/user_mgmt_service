import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

export function middleware(req: NextRequest) {
  const token = req.cookies.get("jwt")?.value
  const isAuthPage = req.nextUrl.pathname === "/login"

  if (!token && !isAuthPage) {
    return NextResponse.redirect(new URL("/login", req.url))
  }

  if (token && isAuthPage) {
    return NextResponse.redirect(new URL("/dashboard", req.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
}