<script>
  import { createEventDispatcher } from "svelte";
  import { GraduationCap } from "lucide-svelte";
  import { supabase } from "../lib/supabase";
  import { Input, Label, Button, Checkbox, Alert } from "flowbite-svelte";

  const dispatch = createEventDispatcher();

  let instructor_user_id = "";
  let password = "";
  let errorMessage = "";
  let isLoading = false;

  /**
   * @param {Event} event
   */
  async function handleSubmit(event) {
    event.preventDefault();
    errorMessage = "";
    isLoading = true;

    try {
      const { data, error } = await supabase
        .from("instructor")
        .select("*")
        .eq("instructor_user_id", instructor_user_id)
        .single();

      if (error || !data) {
        errorMessage = "Invalid credentials. Try again.";
        return;
      }

      if (data.password === password) {
        // Generate a completely random session ID
        const sessionId =
          Math.random().toString(36).substring(2, 15) + Date.now().toString(36);

        // Store only a random session ID - no sensitive data
        await setSecureSession(sessionId, data.instructor_user_id);

        window.location.hash = "#/dashboard";
        dispatch("login");
      } else {
        errorMessage = "Incorrect password.";
      }
    } catch (err) {
      errorMessage = "An error occurred. Please try again.";
    } finally {
      isLoading = false;
    }
  }

  // Function to set secure session - stores only random session ID
  /**
   * @param {string} sessionId
   * @param {string} instructorId
   */
  async function setSecureSession(sessionId, instructorId) {
    // Store only random session ID - no sensitive data visible
    sessionStorage.setItem("session_id", sessionId);
    sessionStorage.setItem("user_id", instructorId);
  }
</script>

<div class="min-h-[90vh] flex items-center justify-center">
  <form
    class="w-full max-w-sm bg-white p-6 rounded-md shadow"
    on:submit={handleSubmit}
  >
    <div
      class="flex flex-col items-center justify-center p-6 border-b border-green-100"
    >
      <img
        src="/Group 2.png"
        alt="EasyGrade Logo"
        class="h-12 w-auto object-contain"
      />
      <p class="mt-2 text-md font-medium text-gray-600">
        The only thing <span class="text-green-700 font-bold"> Easy </span> is the
        grading
      </p>
    </div>

    {#if errorMessage}
      <Alert
        class="mt-3 text-sm text-red-500 text-center p-2 bg-red-100 border-2 rounded-sm border-red-300"
      >
        {errorMessage}
      </Alert>
    {/if}

    <Label
      for="instructor-id"
      class="block mt-4 text-sm font-medium text-gray-700">Instructor ID</Label
    >
    <Input
      id="instructor-id"
      type="text"
      class="mt-1 w-full border rounded-sm px-3 py-2 outline-none focus:ring-2 focus:ring-green-500"
      bind:value={instructor_user_id}
      placeholder="Enter your instructor ID"
      required
    />

    <Label for="password" class="block mt-4 text-sm font-medium text-gray-700"
      >Password</Label
    >
    <Input
      id="password"
      type="password"
      class="mt-1 w-full border rounded-sm px-3 py-2 outline-none focus:ring-2 focus:ring-green-500"
      bind:value={password}
      placeholder="Enter your password"
      required
    />

    <Button
      type="submit"
      class="mt-6 w-full bg-green-700 text-white py-2 rounded-sm hover:bg-green-800 disabled:opacity-50 disabled:cursor-not-allowed"
      disabled={isLoading}
    >
      {isLoading ? "Signing in..." : "Log in"}
    </Button>
  </form>
</div>
