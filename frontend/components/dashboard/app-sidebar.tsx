"use client"

import * as React from "react"

import { NavMain } from "@/components/dashboard/nav-main"
import { NavProjects } from "@/components/dashboard/nav-projects"
import { NavSecondary } from "@/components/dashboard/nav-secondary"
import { NavUser } from "@/components/dashboard/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { HugeiconsIcon } from "@hugeicons/react"
import { ComputerTerminalIcon, RoboticIcon, BookOpen02Icon, Settings05Icon, ChartRingIcon, SentIcon, CropIcon, PieChartIcon, MapsIcon, CommandIcon, SunIcon } from "@hugeicons/core-free-icons"
import {User} from "@/models/user";

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const [user, setUser] = React.useState<User | null>(null)

  React.useEffect(() => {
    const fetchUser = async () => {
      try {
        const res = await fetch("/api/me", {
          method: "GET",
          credentials: "include",
        })

        if (!res.ok) throw new Error("Failed to load user")

        const data = await res.json()
        setUser(data)
      } catch (err) {
        console.error(err)
      }
    }

    fetchUser()
  }, [])

  const data = {
    user: {
      name: user?.firstName + " " + user?.lastName || "",
      email: user?.email || "",
      avatar: "/avatars/shadcn.jpg"
    },
    navMain: [
      {
        title: "Playground",
        url: "#",
        icon: (
            <HugeiconsIcon icon={ComputerTerminalIcon} strokeWidth={2} />
        ),
        isActive: true,
        items: [
          {
            title: "History",
            url: "#",
          }
        ],
      }
    ],
    navSecondary: [
      {
        title: "Support",
        url: "#",
        icon: (
            <HugeiconsIcon icon={ChartRingIcon} strokeWidth={2} />
        ),
      },
      {
        title: "Feedback",
        url: "#",
        icon: (
            <HugeiconsIcon icon={SentIcon} strokeWidth={2} />
        ),
      }
    ],
    projects: [
      {
        name: "Prompt Engineering",
        url: "#",
        icon: (
            <HugeiconsIcon icon={CropIcon} strokeWidth={2} />
        ),
      },
      {
        name: "Sales & Marketing",
        url: "#",
        icon: (
            <HugeiconsIcon icon={PieChartIcon} strokeWidth={2} />
        ),
      }
    ],
  }

  return (
    <Sidebar variant="inset" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <a href="#">
                <div className="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
                  <HugeiconsIcon icon={CommandIcon} strokeWidth={2} className="size-4" />
                </div>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">Lorem Inc</span>
                  <span className="truncate text-xs">Enterprise</span>
                </div>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={data.navMain} />
        <NavProjects projects={data.projects} />
        <NavSecondary items={data.navSecondary} className="mt-auto" />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={data.user} />
      </SidebarFooter>
    </Sidebar>
  )
}
