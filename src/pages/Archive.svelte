<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../lib/supabase';
  import { fly } from 'svelte/transition';
  import { Archive, RefreshCw, Trash2, BadgeCheckIcon, Loader, PackageOpen, ArchiveX } from 'lucide-svelte';
  import { Button, Toast, Input, Label } from 'flowbite-svelte';

  interface SchoolYearJoin {
    school_year_id: number;
    school_year: string;
  }

  interface InstructorJoin {
    instructor_id: number;
    instructor_name: string;
  }

  interface ClassRow {
    class_id: number;
    class_name: string;
    class_code: string;
    section: string;
    is_archived?: boolean | null;
    schoolyear?: SchoolYearJoin | null;
    instructor?: InstructorJoin | null;
  }

  let archivedClasses: ClassRow[] = [];
  let loading = false;
  let query = '';

  // Toast state
  let showToast = false;
  let toastMessage = '';
  let toastType: 'success' | 'error' = 'success';

  function showToastNotification(message: string, type: 'success' | 'error' = 'success') {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => (showToast = false), 3000);
  }

  async function fetchArchived() {
    loading = true;
    const { data, error } = await supabase
      .from('class')
      .select(`
        class_id,
        class_name,
        class_code,
        section,
        is_archived,
        instructor:instructor (instructor_id, instructor_name),
        schoolyear:school_year (school_year_id, school_year)
      `)
      .eq('is_archived', true)
      .order('class_name', { ascending: true });

    if (error) {
      console.error(error);
      showToastNotification('Failed to load archived classes: ' + error.message, 'error');
    } else {
      archivedClasses = (data || []) as unknown as ClassRow[];
    }
    loading = false;
  }

  onMount(fetchArchived);

  async function restoreClass(cls: ClassRow) {
    const { error } = await supabase.from('class').update({ is_archived: false }).eq('class_id', cls.class_id);
    if (error) return showToastNotification('Restore failed: ' + error.message, 'error');
    showToastNotification('Class restored');
    await fetchArchived();
  }

  async function deleteClass(cls: ClassRow) {
    if (!confirm(`Delete "${cls.class_name}"? This cannot be undone.`)) return;
    const { error } = await supabase.from('class').delete().eq('class_id', cls.class_id);
    if (error) return showToastNotification('Delete failed: ' + error.message, 'error');
    showToastNotification('Class deleted');
    await fetchArchived();
  }

  $: filtered = archivedClasses.filter((c) => {
    if (!query.trim()) return true;
    const q = query.toLowerCase();
    return (
      c.class_name.toLowerCase().includes(q) ||
      c.class_code.toLowerCase().includes(q) ||
      c.section.toLowerCase().includes(q) ||
      (c.schoolyear?.school_year || '').toLowerCase().includes(q) ||
      (c.instructor?.instructor_name || '').toLowerCase().includes(q)
    );
  });

  function colorFromId(id: number) {
    // Generate consistent soft color from id
    const colors = ['bg-emerald-600', 'bg-sky-600', 'bg-indigo-600', 'bg-rose-600', 'bg-amber-600', 'bg-cyan-600', 'bg-fuchsia-600'];
    return colors[id % colors.length];
  }
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700"><Archive class="w-5 h-5" /> Archive</h2>
  <p class="mt-2 text-gray-500">Manage archived classes.</p>
</section>
<hr class="my-4 border-gray-200" />

<main class="font-sans">
  <!-- Top bar like Google Classroom: search and count -->
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-3 font-sans">
    <div class="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
      <Input class="w-full sm:w-60 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="Search archived classes..." bind:value={query} />
    </div>
    <div class="text-sm text-gray-600">{filtered.length} archived {filtered.length === 1 ? 'class' : 'classes'}</div>
  </div>

  <!-- Grid of class cards reminiscent of Google Classroom -->
  {#if loading}
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
      {#each Array(6) as _, i}
        <div class="rounded-xl overflow-hidden border border-gray-200 shadow-sm">
          <div class="h-28 bg-gray-200 animate-pulse"></div>
          <div class="p-4 space-y-2">
            <div class="h-4 w-40 bg-gray-200 rounded animate-pulse"></div>
            <div class="h-3 w-24 bg-gray-200 rounded animate-pulse"></div>
            <div class="h-3 w-32 bg-gray-200 rounded animate-pulse"></div>
            <div class="flex gap-2 pt-2">
              <div class="h-9 w-20 bg-gray-200 rounded animate-pulse"></div>
              <div class="h-9 w-20 bg-gray-200 rounded animate-pulse"></div>
            </div>
          </div>
        </div>
      {/each}
    </div>
  {:else if filtered.length === 0}
    <div class="flex flex-col items-center justify-center min-h-[200px] text-gray-500">
      <ArchiveX class="w-12 h-12 mb-3" />
      <span>No archived classes</span>
    </div>
  {:else}
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
      {#each filtered as cls (cls.class_id)}
        <div class="group rounded-xl overflow-hidden border border-gray-200 shadow-sm hover:shadow-md transition-shadow bg-white">
          <!-- Header cover -->
          <div class={`h-28 ${colorFromId(cls.class_id)} relative` }>
            <div class="absolute inset-0 bg-black/10"></div>
            <div class="absolute top-3 left-4 right-4 flex items-start justify-between">
              <div>
                <h3 class="text-white font-semibold text-lg leading-tight">{cls.class_name}</h3>
                <p class="text-white/80 text-xs">{cls.class_code} • {cls.section}</p>
              </div>
            </div>
          </div>
          <!-- Body -->
          <div class="p-4">
            <div class="text-xs text-gray-500 flex items-center justify-between">
              <span>{cls.schoolyear?.school_year || '—'}</span>
              <span>{cls.instructor?.instructor_name || '—'}</span>
            </div>

            <div class="mt-3 flex gap-2">
              <Button class="px-3 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center gap-2" onclick={() => restoreClass(cls)}>
                <RefreshCw class="w-4 h-4" /> Restore
              </Button>
              <Button class="px-3 py-2 bg-white border border-gray-300 text-red-600 rounded-lg hover:bg-red-50 flex items-center gap-2" onclick={() => deleteClass(cls)}>
                <Trash2 class="w-4 h-4" /> Delete
              </Button>
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</main>

{#if showToast}
  <div class="fixed top-4 right-4 z-50">
    <Toast
      class="bg-white border border-gray-200 rounded-lg shadow-lg p-4 flex items-center gap-3 min-w-80"
      transition={fly} params={{ x: 200 }}
    >
      {#snippet icon()}
      <div class="flex-shrink-0">
        {#if toastType === 'success'}
          <div class="w-5 h-5 bg-green-100 rounded-full flex items-center justify-center">
            <BadgeCheckIcon class="w-6 h-6 text-green-600" />
          </div>
        {:else}
          <div class="w-5 h-5 bg-red-100 rounded-full flex items-center justify-center">
            <svg class="w-3 h-3 text-red-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
            </svg>
          </div>
        {/if}
      </div>
      {/snippet}
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-900">{toastMessage}</p>
      </div>
    </Toast>
  </div>
{/if}
