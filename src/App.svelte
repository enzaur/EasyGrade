<script lang="ts">
  import { onMount } from 'svelte'
  import Header from "./components/header.svelte";
  import Dashboard from "./pages/Dashboard.svelte";
  import Classes from "./pages/Classes.svelte";
  import Students from "./pages/Students.svelte";
  import Grades from "./pages/Grades.svelte";
  import Login from "./pages/Login.svelte";
  import Settings from "./pages/settings.svelte";
  import Gradebook from './pages/Gradebook.svelte';
  import Archive from './pages/Archive.svelte';
  import StudentGrade from './pages/StudentGrade.svelte';

  let currentRoute = "#/dashboard";
  let isAuthenticated = false;
  let isLoading = true;

  const routes: Record<string, any> = {
    "#/dashboard": Dashboard,
    "#/classes": Classes,
    "#/students": Students, 
    "#/grades": Grades,
    "#/login": Login,
    "#/settings": Settings,
    "#/gradebook": Gradebook,
    '#/archive': Archive,
    '#/student-grade': StudentGrade
  };

  function checkAuth() {
    isLoading = true;
    
    try {
      const sessionId = sessionStorage.getItem('session_id');
      const userId = sessionStorage.getItem('user_id');
      
      if (!sessionId || !userId) {
        isAuthenticated = false;
        isLoading = false;
        return;
      }

      // Simple validation - just check if session exists
      // In a real app, you'd validate this against your backend
      isAuthenticated = true;
    } catch (error) {
      // Invalid session
      sessionStorage.removeItem('session_id');
      sessionStorage.removeItem('user_id');
      isAuthenticated = false;
    }
    
    isLoading = false;
  }

  function updateRoute() {
    checkAuth();
    const next = window.location.hash || "#/dashboard";
    
    // Allow public access to student grade page
    if (next.startsWith("#/student-grade")) {
      currentRoute = next.split('?')[0]; // Remove query params from route matching
      return;
    }
    
    // Guard unauthenticated access
    if (!isAuthenticated && next !== "#/login") {
      window.location.hash = "#/login";
      currentRoute = "#/login";
      return;
    }
    // Prevent visiting login when authenticated
    if (isAuthenticated && next === "#/login") {
      window.location.hash = "#/dashboard";
      currentRoute = "#/dashboard";
      return;
    }
    currentRoute = next;
  }

  onMount(() => {
    updateRoute();
    window.addEventListener("hashchange", updateRoute);
    
    return () => {
      window.removeEventListener("hashchange", updateRoute);
    };
  });

  $: ActivePage = routes[currentRoute] ?? Dashboard;
</script>

{#if isLoading}
  <div class="min-h-screen flex items-center justify-center bg-gray-50">
    <div class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600 mx-auto"></div>
      <p class="mt-4 text-gray-600">Loading...</p>
    </div>
  </div>
{:else if currentRoute === '#/student-grade'}
  <!-- Public student grade view without authentication -->
  <main class="min-h-screen bg-gray-50">
    <svelte:component this={ActivePage} />
  </main>
{:else if isAuthenticated}
    <div class="flex flex-col min-h-screen">
      <Header />
      <div class="flex flex-1 lg:ml-64 bg-gray-50">
        <main class="flex-1 p-4 lg:p-6 overflow-y-auto">
          <svelte:component this={ActivePage} />
        </main>
      </div>
    </div>
  {:else}
    <main class="min-h-screen bg-gray-50 flex">
      <div class="flex-1 p-4">
        <svelte:component this={ActivePage} />
      </div>
    </main>
  {/if}

