<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import {
    BadgeCheckIcon,
    ClipboardList,
    Frown,
    Loader,
    Notebook,
    NotebookPen,
    Plus,
    Siren,
    X,
  } from "lucide-svelte";
  import { supabase } from "../lib/supabase";
  import type { RealtimeChannel } from "@supabase/supabase-js";
  import {
    Button,
    Input,
    Label,
    Table,
    TableBody,
    TableBodyCell,
    TableBodyRow,
    TableHead,
    TableHeadCell,
    Toast,
  } from "flowbite-svelte";
  import { fly } from "svelte/transition";

  interface SchoolYear {
    school_year_id: number;
    school_year: string;
  }

  interface Instructor {
    instructor_id: number;
    instructor_name: string;
    instructor_user_id: string;
  }

  interface SchoolYearJoin {
    school_year_id: number;
    school_year: string;
  }

  interface InstructorJoin {
    instructor_id: number;
    instructor_name: string;
  }

  interface Class {
    class_id: number;
    class_name: string;
    class_code: string;
    section: string;
    school_year_id?: number;
    instructor_id?: number;
    school_year?: number;
    instructor?: number;
    schoolyear: SchoolYearJoin | null;
    instructor_info: InstructorJoin | null;
    students_count?: number;
  }

  let classes: Class[] = [];
  let schoolYears: SchoolYear[] = [];
  let instructors: Instructor[] = [];
  let search = "";
  let selectedYearId: number | "" = "";
  let showModal = false;
  let editingClass: Class | null = null;
  let deleteModal = false;
  let classToDelete: Class | null = null;
  // Archive mode: we will archive instead of delete
  let showToast = false;
  let toastMessage = "";
  let toastType = "success";

  let newClass = {
    class_name: "",
    class_code: "",
    section: "",
    school_year_id: "",
    instructor_id: "",
  };

  let channel: RealtimeChannel | null = null;

  let loading = false;

  function showToastNotification(
    message: string,
    type: "success" | "error" = "success"
  ) {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => {
      showToast = false;
    }, 3000);
  }

  function resetNewClass() {
    newClass = {
      class_name: "",
      class_code: "",
      section: "",
      school_year_id: "",
      instructor_id: "",
    };
  }

  async function fetchSchoolYears() {
    const { data, error } = await supabase
      .from("schoolyear")
      .select("school_year_id, school_year")
      .order("school_year", { ascending: true });
    if (!error) schoolYears = data || [];
  }

  async function fetchInstructors() {
    const { data, error } = await supabase
      .from("instructor")
      .select("instructor_id, instructor_name")
      .order("instructor_name", { ascending: true });
    if (!error) instructors = data || [];
  }

  async function fetchClasses() {
  loading = true;
  const { data, error } = await supabase
    .from("class")
    .select(`
      class_id,
      class_name,
      class_code,
      section,
      instructor,
      school_year,
      instructor:instructor (instructor_id, instructor_name),
      schoolyear:school_year (school_year_id, school_year),
      students:student(count)
    `)
    .filter("is_archived", "eq", false)
    .order("class_name", { ascending: true });

  if (error) {
    console.error("Fetch error:", error);
  } else {
    // Map count from related students aggregate
    classes = (data || []).map((c: any) => ({
      ...c,
      students_count: Array.isArray(c.students) && c.students.length > 0 && typeof c.students[0].count === 'number'
        ? c.students[0].count
        : 0,
    }));
  }

  loading = false;
}


  async function addClass() {
    const instructorId = Number(newClass.instructor_id);
    const schoolYearId = Number(newClass.school_year_id);

    if (!instructorId || !schoolYearId) {
      alert("Instructor and School Year are required");
      return;
    }

    loading = true;
    const { error } = await supabase.from("class").insert([
      {
        class_name: newClass.class_name,
        class_code: newClass.class_code,
        section: newClass.section,
        school_year: schoolYearId,
        instructor: instructorId,
      },
    ]);

    if (error) {
      console.error("Error adding class:", error);
      showToastNotification("Error adding class: " + error.message, "error");
    } else {
      showModal = false;
      resetNewClass();
      await fetchClasses();
      showToastNotification("Class added successfully!");
    }
  }

  function openEdit(cls: Class) {
    editingClass = cls;
    newClass = {
      class_name: cls.class_name,
      class_code: cls.class_code,
      section: cls.section,
      school_year_id: cls.schoolyear?.school_year_id?.toString() || "",
      instructor_id: cls.instructor?.instructor_id?.toString() || "",
    };
    showModal = true;
  }

  async function updateClass() {
    if (!editingClass) return;

    const instructorId = Number(newClass.instructor_id);
    const schoolYearId = Number(newClass.school_year_id);

    if (
      !newClass.class_name ||
      !newClass.class_code ||
      !newClass.section ||
      !instructorId ||
      !schoolYearId
    ) {
      alert("All fields are required");
      return;
    }

    const updateData = {
      class_name: newClass.class_name,
      class_code: newClass.class_code,
      section: newClass.section,
      school_year: schoolYearId,
      instructor: instructorId,
    };

    const { error } = await supabase
      .from("class")
      .update(updateData)
      .eq("class_id", editingClass.class_id);

    if (error) {
      showToastNotification("Error updating class: " + error.message, "error");
      return;
    }

    showModal = false;
    editingClass = null;
    resetNewClass();
    await fetchClasses();
    showToastNotification("Class updated successfully!");
  }

  function openDeleteModal(cls: Class) {
    classToDelete = cls;
    deleteModal = true;
  }

  async function confirmDelete() {
    if (!classToDelete) return;

    loading = true;
    const { error } = await supabase
      .from("class")
      .update({ is_archived: true })
      .eq("class_id", classToDelete.class_id);

    if (error) {
      showToastNotification("Error archiving class: " + error.message, "error");
    } else {
      showToastNotification("Class archived successfully!");
      await fetchClasses();
    }

    deleteModal = false;
    classToDelete = null;
    loading = false;
  }

  function openAddModal() {
    editingClass = null;
    resetNewClass();
    showModal = true;
  }

  onMount(async () => {
    await fetchSchoolYears();
    await fetchInstructors();
    await fetchClasses();

    channel = supabase
      .channel("class-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "class" },
        async () => {
          await fetchClasses();
        }
      )
      .subscribe();
  });

  onDestroy(() => {
    if (channel) supabase.removeChannel(channel);
  });

  $: filteredClasses = classes.filter(
    (c) =>
      (!search || c.class_name.toLowerCase().includes(search.toLowerCase())) &&
      (!selectedYearId ||
        c.schoolyear?.school_year_id === Number(selectedYearId))
  );
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700">
    <ClipboardList class="w-5 h-5" /> Classes
  </h2>
  <p class="mt-1 text-gray-500">Manage your classes here.</p>
</section>

<hr class="my-4 border-gray-200" />

<main>
  <div
    class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-3 font-sans"
  >
    <div class="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
      <Input
        type="text"
        placeholder="Search classes..."
        class="w-full sm:w-60 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
        bind:value={search}
      />

      <select
        class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
        bind:value={selectedYearId}
      >
        <option value="">All School Year</option>
        {#each schoolYears as sy}
          <option value={sy.school_year_id}>{sy.school_year}</option>
        {/each}
      </select>
    </div>

    <Button
      onclick={openAddModal}
      class="flex items-center justify-center gap-2 bg-green-600 text-white rounded-lg shadow-md px-4 py-3 hover:shadow-lg transition-shadow duration-200 w-full sm:w-auto hover:bg-green-700"
    >
      <NotebookPen class="w-5 h-5" /> Add Class
    </Button>
  </div>

  <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
    <div class="overflow-x-auto">
      <Table class="w-full">
        <TableHead class="bg-gray-100">
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Code</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Name</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Section</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >School Year</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Instructor</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Students</TableHeadCell
          >
          <TableHeadCell
            class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >Actions</TableHeadCell
          >
        </TableHead>
        <TableBody class="bg-white divide-y divide-gray-200">
          {#if loading}
            {#each Array(5) as _, i (i)}
              <TableBodyRow class="hover:bg-gray-50">
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-16"></div>
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-32"></div>
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-24"></div>
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-20"></div>
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-28"></div>
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2">
                  <div class="flex gap-2">
                    <div class="h-6 bg-gray-200 rounded animate-pulse w-12"></div>
                    <div class="h-6 bg-gray-200 rounded animate-pulse w-16"></div>
                  </div>
                </TableBodyCell>
              </TableBodyRow>
            {/each}
          {:else}
            {#if filteredClasses.length === 0}
              <TableBodyRow>
                <TableBodyCell colspan="6" class="p-0">
                  <div class="flex flex-col items-center justify-center min-h-[120px] text-gray-500">
                    <Frown class="w-8 h-8 mb-2 text-gray-400" />
                    <span>No classes found</span>
                  </div>
                </TableBodyCell>
              </TableBodyRow>
            {:else}
              {#each filteredClasses as cls (cls.class_id)}
                <TableBodyRow class="hover:bg-gray-50">
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs font-medium text-gray-700 border-r border-gray-200">
                    {cls.class_code}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                    {cls.class_name}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                    {cls.section}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                    {cls.schoolyear?.school_year || ""}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                    {cls.instructor?.instructor_name || ""}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                    {cls.students_count ?? 0}
                  </TableBodyCell>
                  <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs">
                    <div class="flex items-center gap-2">
                      <button onclick={() => openEdit(cls)} class="text-blue-600 hover:text-blue-900 text-xs px-2 py-1">
                        Edit
                      </button>
                      <button onclick={() => openDeleteModal(cls)} class="text-red-600 hover:text-red-900 text-xs px-2 py-1">
                        Archive
                      </button>
                    </div>
                  </TableBodyCell>
                </TableBodyRow>
              {/each}
            {/if}
          {/if}
        </TableBody>
        
      </Table>
    </div>
  </div>

  {#if showModal}
    <div
      class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans"
    >
      <div
        class="bg-white rounded-lg shadow-lg w-full max-w-md p-4 sm:p-6 relative"
      >
        <button
          onclick={() => (showModal = false)}
          class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
        >
          <X class="w-5 h-5" />
        </button>

        <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
          {editingClass ? "Edit Class" : "Add Class"}
        </Label>

        <div class="space-y-3">
          <Input
            type="text"
            placeholder="Class Code"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
            bind:value={newClass.class_code}
          />
          <Input
            type="text"
            placeholder="Class Name"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
            bind:value={newClass.class_name}
          />
          <Input
            type="text"
            placeholder="Section"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
            bind:value={newClass.section}
          />

          <select
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
            bind:value={newClass.instructor_id}
          >
            <option value="">Select Instructor</option>
            {#each instructors as inst}
              <option value={inst.instructor_id.toString()}
                >{inst.instructor_name}</option
              >
            {/each}
          </select>

          <select
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
            bind:value={newClass.school_year_id}
          >
            <option value="">Select School Year</option>
            {#each schoolYears as sy}
              <option value={sy.school_year_id.toString()}
                >{sy.school_year}</option
              >
            {/each}
          </select>
        </div>

        <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
          <Button
            onclick={() => (showModal = false)}
            class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
            >Cancel</Button
          >
          <Button
            onclick={editingClass ? updateClass : addClass}
            class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            disabled={loading}
          >
            {#if loading}
              <Loader class="w-4 h-4 animate-spin" />
            {/if}
            {editingClass ? "Update" : "Add"}
          </Button>
        </div>
      </div>
    </div>
  {/if}

  {#if deleteModal && classToDelete}
    <div
      class="fixed inset-0 flex items-center justify-center bg-black/50 z-50"
    >
      <div
        class="bg-white rounded-lg shadow-lg w-full max-w-sm sm:max-w-md p-6 text-center relative"
      >
        <Siren class="mx-auto mb-4 h-12 w-12 text-red-400" />
        <Label class="mb-5 text-lg font-semibold text-gray-700">
          Archive this class?<br>"{classToDelete.class_name}"
        </Label>
        <p class="text-sm text-gray-500 mb-5">You can restore it from Archive later.</p>
        <div class="mt-5 flex flex-col sm:flex-row justify-center gap-3">
          <Button
            onclick={() => (deleteModal = false)}
            class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
            disabled={loading}>Cancel</Button
          >
          <Button
            onclick={confirmDelete}
            class="w-full sm:w-auto px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            disabled={loading}
          >
            {#if loading}
              <Loader class="w-4 h-4 animate-spin" />
            {/if}
            Yes, Archive
          </Button>
        </div>
      </div>
    </div>
  {/if}

  {#if showToast}
    <div class="fixed top-4 right-4 z-50">
      <Toast
        class="bg-white border border-gray-200 rounded-lg shadow-lg p-4 flex items-center gap-3 min-w-80"
        transition={fly}
        params={{ x: 200 }}
      >
        {#snippet icon()}
          <div class="flex-shrink-0">
            {#if toastType === "success"}
              <div
                class="w-5 h-5 bg-green-100 rounded-full flex items-center justify-center"
              >
                <BadgeCheckIcon class="w-6 h-6 text-green-600" />
              </div>
            {:else}
              <div
                class="w-5 h-5 bg-red-100 rounded-full flex items-center justify-center"
              >
                <svg
                  class="w-3 h-3 text-red-600"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path
                    fill-rule="evenodd"
                    d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  ></path>
                </svg>
              </div>
            {/if}
          </div>
        {/snippet}
        <div class="flex-1">
          <p class="text-sm font-medium text-gray-900">{toastMessage}</p>
        </div>
        <!-- <button
        onclick={() => (showToast = false)}
        class="flex-shrink-0 text-gray-400 hover:text-gray-600"
      >
      </button> -->
      </Toast>
    </div>
  {/if}
</main>
