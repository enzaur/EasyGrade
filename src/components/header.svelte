<script lang="ts">
  import {
    LayoutDashboard,
    Users,
    Calendar,
    ClipboardList,
    BarChart3,
    LogOut,
    Menu,
    X,
    Settings2,
    Settings,
    Notebook,
    Table,
    Archive,
    ArchiveIcon,
    Table2,
  } from "lucide-svelte";
  import { link, location } from "svelte-spa-router";
  import { derived } from "svelte/store";

  const current = derived(location, ($location) => $location);
  $: currentPath = $location;

  const isActive = (path: string): boolean => currentPath === path;

  let mobileMenuOpen = false;

  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
  }

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }

  function handleLogout() {
    sessionStorage.removeItem("session_id");
    sessionStorage.removeItem("user_id");
    window.location.hash = "#/login";
  }
</script>

<!-- Desktop Sidebar -->
<aside
  class="hidden lg:flex flex-col w-64 bg-white border-r border-green-100 fixed top-0 bottom-0 left-0 shadow-xl z-30 font-sans"
>
  <!-- Logo Section -->
  <div class="flex items-center justify-center p-6 border-b border-green-100">
    <img
      src="/Group 2.png"
      alt="EasyGrade Logo"
      class="h-12 w-auto object-contain"
    />
  </div>

  <!-- Navigation -->
  <nav class="flex flex-col flex-1 px-4 py-6 space-y-2">
    <a
      use:link
      href="/dashboard"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive("/dashboard")}
      class:text-white={isActive("/dashboard")}
      class:shadow-md={isActive("/dashboard")}
    >
      <LayoutDashboard class="w-5 h-5" />
      <span class="font-medium">Dashboard</span>
    </a>

    <a
      use:link
      href="/classes"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive("/classes")}
      class:text-white={isActive("/classes")}
      class:shadow-md={isActive("/classes")}
    >
      <ClipboardList class="w-5 h-5" />
      <span class="font-medium">Classes</span>
    </a>

    <a
      use:link
      href="/students"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive("/students")}
      class:text-white={isActive("/students")}
      class:shadow-md={isActive("/students")}
    >
      <Users class="w-5 h-5" />
      <span class="font-medium">Students</span>
    </a>

    <a
    use:link
    href="/gradebook"
    class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
    class:bg-green-600={isActive("/gradebook")}
    class:text-white={isActive("/gradebook")}
    class:shadow-md={isActive("/gradebook")}
  >
    <Table2 class="w-5 h-5" />
    <span class="font-medium">Grade Book</span>
  </a>

    <a
      use:link
      href="/settings"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive("/settings")}
      class:text-white={isActive("/settings")}
      class:shadow-md={isActive("/settings")}
    >
      <Settings class="w-5 h-5" />
      <span class="font-medium">Settings</span>
    </a>

    <a
    use:link
    href="/archive"
    class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
    class:bg-green-600={isActive("/archive")}
    class:text-white={isActive("/archive")}
    class:shadow-md={isActive("/archive")}
  >
    <Archive class="w-5 h-5" />
    <span class="font-medium">Archive</span>
  </a>

    <!-- <a use:link href="/terms"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive('/terms')}
      class:text-white={isActive('/terms')}
      class:shadow-md={isActive('/terms')}>
      <Calendar class="w-5 h-5" />
      <span class="font-medium">Terms</span>
    </a>

    <a use:link href="/components"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive('/components')}
      class:text-white={isActive('/components')}
      class:shadow-md={isActive('/components')}>
      <ClipboardList class="w-5 h-5" />
      <span class="font-medium">Components</span>
    </a>

    <a use:link href="/grades"
      class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
      class:bg-green-600={isActive('/grades')}
      class:text-white={isActive('/grades')}
      class:shadow-md={isActive('/grades')}>
      <BarChart3 class="w-5 h-5" />
      <span class="font-medium">Grades</span>
    </a> -->
  </nav>

  <!-- Logout Button -->
  <div class="p-4 border-t border-green-100">
    <button
      class="flex items-center gap-3 w-full px-4 py-3 text-gray-700 hover:bg-red-50 hover:text-red-600 rounded-xl transition-all duration-200 group"
      on:click={handleLogout}
    >
      <LogOut class="w-5 h-5" />
      <span class="font-medium">Logout</span>
    </button>
  </div>
</aside>

<!-- Mobile Header -->
<header
  class="lg:hidden bg-white border-b border-gray-200 shadow-sm sticky top-0 z-40 font-sans"
>
  <div class="flex items-center justify-between px-4 py-3">
    <div class="flex items-center gap-3">
      <img src="/Group 2.png" alt="EasyGrade Logo" class="h-8 w-auto" />
    </div>
    <button
      class="p-2 rounded-lg text-gray-600 hover:bg-gray-100 transition-colors"
      on:click={toggleMobileMenu}
    >
      {#if mobileMenuOpen}
        <X class="w-6 h-6" />
      {:else}
        <Menu class="w-6 h-6" />
      {/if}
    </button>
  </div>
</header>

<!-- Mobile Sidebar Overlay -->
{#if mobileMenuOpen}
  <div
    class="lg:hidden fixed inset-0 z-50 font-sans bg-black/40 backdrop-blur-sm"
  >
    <!-- Backdrop -->
    <div
      class="absolute inset-0 bg-opacity-50"
      role="button"
      tabindex="0"
      on:click={closeMobileMenu}
      on:keydown={(e) => e.key === "Enter" && closeMobileMenu()}
      aria-label="Close mobile menu"
    ></div>

    <!-- Sidebar -->
    <aside class="relative w-80 max-w-sm h-full bg-white shadow-xl font-sans">
      <!-- Header -->
      <div
        class="flex items-center justify-between p-4 border-b border-gray-200"
      >
        <div class="flex items-center gap-3">
          <img src="/Group 2.png" alt="EasyGrade Logo" class="h-8 w-auto" />
        </div>
        <button
          class="p-2 rounded-lg text-gray-600 hover:bg-gray-100 transition-colors"
          on:click={closeMobileMenu}
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Navigation -->
      <nav class="flex flex-col px-4 py-6 space-y-2">
        <a
          use:link
          href="/dashboard"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/dashboard")}
          class:text-white={isActive("/dashboard")}
          on:click={closeMobileMenu}
        >
          <LayoutDashboard class="w-5 h-5" />
          <span class="font-medium">Dashboard</span>
        </a>

        <a
          use:link
          href="/classes"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/classes")}
          class:text-white={isActive("/classes")}
          on:click={closeMobileMenu}
        >
          <ClipboardList class="w-5 h-5" />
          <span class="font-medium">Classes</span>
        </a>

        <a
          use:link
          href="/students"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/students")}
          class:text-white={isActive("/students")}
          on:click={closeMobileMenu}
        >
          <Users class="w-5 h-5" />
          <span class="font-medium">Students</span>
        </a>

        <a
        use:link
        href="/gradebook"
        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
        class:bg-green-600={isActive("/gradebook")}
        class:text-white={isActive("/gradebook")}
        class:shadow-md={isActive("/gradebook")}
      >
        <Table2 class="w-5 h-5" />
        <span class="font-medium">Grade Book</span>
      </a>

        <a
          use:link
          href="/settings"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
          class:bg-green-600={isActive("/settings")}
          class:text-white={isActive("/settings")}
          class:shadow-md={isActive("/settings")}
        >
          <Settings class="w-5 h-5" />
          <span class="font-medium">Settings</span>
        </a>

        <a
        use:link
        href="/archive"
        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200 group"
        class:bg-green-600={isActive("/archive")}
        class:text-white={isActive("/archive")}
        class:shadow-md={isActive("/archive")}
      >
        <ArchiveIcon class="w-5 h-5" />
        <span class="font-medium">Archive</span>
      </a>
        

        <!-- <a
          use:link
          href="/terms"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/terms")}
          class:text-white={isActive("/terms")}
          on:click={closeMobileMenu}
        >
          <Calendar class="w-5 h-5" />
          <span class="font-medium">Terms</span>
        </a>

        <a
          use:link
          href="/components"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/components")}
          class:text-white={isActive("/components")}
          on:click={closeMobileMenu}
        >
          <ClipboardList class="w-5 h-5" />
          <span class="font-medium">Components</span>
        </a>

        <a
          use:link
          href="/grades"
          class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 hover:bg-green-100 hover:text-green-700 transition-all duration-200"
          class:bg-green-600={isActive("/grades")}
          class:text-white={isActive("/grades")}
          on:click={closeMobileMenu}
        >
          <BarChart3 class="w-5 h-5" />
          <span class="font-medium">Grades</span>
        </a> -->
      </nav>

      <!-- Logout Button -->
      <div
        class="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200"
      >
        <button
          class="flex items-center gap-3 w-full px-4 py-3 text-gray-700 hover:bg-red-50 hover:text-red-600 rounded-xl transition-all duration-200"
          on:click={handleLogout}
        >
          <LogOut class="w-5 h-5" />
          <span class="font-medium">Logout</span>
        </button>
      </div>
    </aside>
  </div>
{/if}

<!-- Mobile Bottom Navigation -->
<!-- <nav class="lg:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg z-30">
  <div class="grid grid-cols-4">
    <a use:link href="/dashboard"
      class="flex flex-col items-center justify-center py-3 px-2 text-xs transition-all duration-200"
      class:bg-green-50={isActive('/dashboard')}
      class:text-green-600={isActive('/dashboard')}
      class:text-gray-500={!isActive('/dashboard')}>
      <LayoutDashboard class="w-6 h-6 mb-1" />
      <span class="font-medium">Dashboard</span>
    </a>

    <a use:link href="/classes"
      class="flex flex-col items-center justify-center py-3 px-2 text-xs transition-all duration-200"
      class:bg-green-50={isActive('/classes')}
      class:text-green-600={isActive('/classes')}
      class:text-gray-500={!isActive('/classes')}>
      <ClipboardList class="w-6 h-6 mb-1" />
      <span class="font-medium">Classes</span>
    </a>

    <a use:link href="/students"
      class="flex flex-col items-center justify-center py-3 px-2 text-xs transition-all duration-200"
      class:bg-green-50={isActive('/students')}
      class:text-green-600={isActive('/students')}
      class:text-gray-500={!isActive('/students')}>
      <Users class="w-6 h-6 mb-1" />
      <span class="font-medium">Students</span>
    </a>

    <a use:link href="/grades"
      class="flex flex-col items-center justify-center py-3 px-2 text-xs transition-all duration-200"
      class:bg-green-50={isActive('/grades')}
      class:text-green-600={isActive('/grades')}
      class:text-gray-500={!isActive('/grades')}>
      <BarChart3 class="w-6 h-6 mb-1" />
      <span class="font-medium">Grades</span>
    </a>
  </div>
</nav> -->
