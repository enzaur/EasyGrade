<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../lib/supabase';
  import { fly } from 'svelte/transition';
  import { Settings, BadgeCheckIcon } from 'lucide-svelte';

  import { Button, Input, Label, Toast } from 'flowbite-svelte';


  interface SchoolYear { school_year_id: number; school_year: string }
  interface Term { term_id: number; term_name: string }
  interface GradeComponent { component_id: number; component_name: string }
  interface GradeComponentItem { item_id: number; title: string; number_of_items: number; component_id: number }
  interface GradePercentage { percentage_id: number; percentage: number; component: number }

  // Data lists
  let schoolYears: SchoolYear[] = [];
  let terms: Term[] = [];
  let components: GradeComponent[] = [];
  let componentItems: GradeComponentItem[] = [];
  let percentages: GradePercentage[] = [];

  // UI state
  let loading = false;
  let showToast = false;
  let toastMessage = '';
  let toastType: 'success' | 'error' = 'success';

  function showToastNotification(message: string, type: 'success' | 'error' = 'success') {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => (showToast = false), 3000);
  }

  function startNewAccount() {
    isCreatingAccount = true;
    isEditingAccount = false;
    selectedInstructorId = '';
    nameDraft = '';
    userIdDraft = '';
    passwordDraft = '';
    confirmPasswordDraft = '';
  }

  function cancelAccountEdit() {
    isCreatingAccount = false;
    isEditingAccount = false;
    syncNameDraft();
  }

  async function addAccount() {
    const name = nameDraft.trim();
    const userId = userIdDraft.trim();
    const pwd = passwordDraft;
    if (!name || !userId || !pwd || pwd !== confirmPasswordDraft) {
      if (pwd !== confirmPasswordDraft) showToastNotification('Passwords do not match', 'error');
      return;
    }
    if (pwd.length < 6) {
      showToastNotification('Password must be at least 6 characters', 'error');
      return;
    }
    const { data, error } = await supabase
      .from('instructor')
      .insert([{ instructor_name: name, instructor_user_id: userId, password: pwd }])
      .select('instructor_id');
    if (error) {
      showToastNotification('Error adding account: ' + error.message, 'error');
      return;
    }
    await loadInstructors();
    const newId = data?.[0]?.instructor_id;
    if (newId) {
      selectedInstructorId = newId;
      persistSelectedInstructor();
    }
    isCreatingAccount = false;
    showToastNotification('Account created');
  }

  async function deleteAccount() {
    const id = Number(selectedInstructorId);
    if (!id) return;
    const ok = window.confirm('Delete this account? This cannot be undone.');
    if (!ok) return;
    const { error } = await supabase.from('instructor').delete().eq('instructor_id', id);
    if (error) {
      showToastNotification('Error deleting account: ' + error.message, 'error');
      return;
    }
    await loadInstructors();
    selectedInstructorId = '';
    nameDraft = '';
    localStorage.removeItem('current_instructor_id');
    showToastNotification('Account deleted');
  }

  // Forms
  let newSchoolYear = '';
  let selectedCurrentSY: string | number = '';

  let newTermName = '';
  let editingTerm: Term | null = null;

  let newComponentName = '';
  let editingComponent: GradeComponent | null = null;

  // component items form
  let selectedComponentForItems: string | number = '';
  let newItemTitle = '';
  let newItemCount: number | '' = 1;
  let editingItem: GradeComponentItem | null = null;


  let newComponentPercentage: number | '' = '';

  let isEditingAccount = false;
  let isCreatingAccount = false;


  async function fetchAll() {
    loading = true;
    try {
      const [sy, trm, comp, compItems, gp] = await Promise.all([
        supabase.from('schoolyear').select('school_year_id, school_year').order('school_year', { ascending: true }),
        supabase.from('term').select('term_id, term_name').order('term_name', { ascending: true }),
        supabase.from('grade_component').select('component_id, component_name').order('component_name', { ascending: true }),
        supabase.from('grade_component_items').select('item_id, title, number_of_items, component_id').order('title', { ascending: true }),
        supabase.from('grade_percentage').select('percentage_id, percentage, component')
      ]);

      if (!sy.error) schoolYears = sy.data || [];
      if (!trm.error) terms = trm.data || [];
      if (!comp.error) components = comp.data || [];
      if (!compItems.error) componentItems = compItems.data || [];
      if (!gp.error) percentages = gp.data || [];
    } catch (e) {
      console.error(e);
      showToastNotification('Failed to load settings', 'error');
    } finally {
      loading = false;
    }
  }

  onMount(fetchAll);

  // School Year actions
  async function addSchoolYear() {
    const value = newSchoolYear.trim();
    if (!value) return;
    const { error } = await supabase.from('schoolyear').insert([{ school_year: value }]);
    if (error) return showToastNotification('Error adding school year: ' + error.message, 'error');
    newSchoolYear = '';
    await fetchAll();
    showToastNotification('School year added');
  }

  // Optionally set a current school year setting in a settings table. If not available, skip persist and simply keep selected in UI
  async function setCurrentSchoolYear() {
    if (!selectedCurrentSY) return;
    // If you have a settings table, persist here. For now, just notify.
    showToastNotification('Current school year set');
  }

  // Terms actions
  function startEditTerm(term: Term) {
    editingTerm = term;
    newTermName = term.term_name;
  }
  function cancelEditTerm() {
    editingTerm = null;
    newTermName = '';
  }
  async function saveTerm() {
    const value = newTermName.trim();
    if (!value) return;
    if (editingTerm) {
      const { error } = await supabase.from('term').update({ term_name: value }).eq('term_id', editingTerm.term_id);
      if (error) return showToastNotification('Error updating term: ' + error.message, 'error');
      showToastNotification('Term updated');
    } else {
      const { error } = await supabase.from('term').insert([{ term_name: value }]);
      if (error) return showToastNotification('Error adding term: ' + error.message, 'error');
      showToastNotification('Term added');
    }
    newTermName = '';
    editingTerm = null;
    await fetchAll();
  }
  async function deleteTerm(term: Term) {
    const { error } = await supabase.from('term').delete().eq('term_id', term.term_id);
    if (error) return showToastNotification('Error deleting term: ' + error.message, 'error');
    showToastNotification('Term deleted');
    await fetchAll();
  }

  // Grade Components actions
  function startEditComponent(c: GradeComponent) {
    editingComponent = c;
    newComponentName = c.component_name;
    newComponentPercentage = getPercentageForComponent(c.component_id)?.percentage ?? '';
  }
  function cancelEditComponent() {
    editingComponent = null;
    newComponentName = '';
    newComponentPercentage = '';
  }
  async function saveComponent() {
    const name = newComponentName.trim();
    const perc = Number(newComponentPercentage);
    if (!name || isNaN(perc) || perc < 0 || perc > 100) return;
    let compId: number;
    if (editingComponent) {
      const { error } = await supabase
        .from('grade_component')
        .update({ component_name: name })
        .eq('component_id', editingComponent.component_id);
      if (error) return showToastNotification('Error updating component: ' + error.message, 'error');
      compId = editingComponent.component_id;

    } else {

      const { data, error } = await supabase
        .from('grade_component')
        .insert([{ component_name: name }])
        .select('component_id');
      if (error) return showToastNotification('Error adding component: ' + error.message, 'error');
      compId = data?.[0]?.component_id;

    }

    // Handle percentage
    const existingPerc = getPercentageForComponent(compId);
    if (existingPerc) {
      const { error } = await supabase
        .from('grade_percentage')
        .update({ percentage: perc })
        .eq('percentage_id', existingPerc.percentage_id);
      if (error) return showToastNotification('Error updating percentage: ' + error.message, 'error');
    } else {
      const { error } = await supabase
        .from('grade_percentage')
        .insert([{ percentage: perc, component: compId }]);
      if (error) return showToastNotification('Error adding percentage: ' + error.message, 'error');
    }
    cancelEditComponent();
    await fetchAll();
    showToastNotification(editingComponent ? 'Component updated' : 'Component added');
  }
  async function deleteComponent(c: GradeComponent) {
    const { error } = await supabase.from('grade_component').delete().eq('component_id', c.component_id);
    if (error) return showToastNotification('Error deleting component: ' + error.message, 'error');
    showToastNotification('Component deleted');
    await fetchAll();
  }

  // Component items actions
  function itemsForComponent(id: number) {
    return componentItems.filter((i) => i.component_id === id);
  }
  function startEditItem(item: GradeComponentItem) {
    editingItem = item;
    selectedComponentForItems = item.component_id;
    newItemTitle = item.title;
    newItemCount = item.number_of_items;
  }
  function cancelEditItem() {
    editingItem = null;
    selectedComponentForItems = '';
    newItemTitle = '';
    newItemCount = 1;
  }
  async function saveItem() {
    const compId = Number(selectedComponentForItems);
    const title = newItemTitle.trim();
    const count = Number(newItemCount);
    if (!compId || !title || !count) return;

    if (editingItem) {
      const { error } = await supabase
        .from('grade_component_items')
        .update({ title, number_of_items: count, component_id: compId })
        .eq('item_id', editingItem.item_id);
      if (error) return showToastNotification('Error updating item: ' + error.message, 'error');
      showToastNotification('Item updated');
    } else {
      const { error } = await supabase
        .from('grade_component_items')
        .insert([{ title, number_of_items: count, component_id: compId, class_id: 1 }]);
      // Note: class_id is required by schema; replace 1 with actual selected class context if available
      if (error) return showToastNotification('Error adding item: ' + error.message, 'error');
      showToastNotification('Item added');
    }
    cancelEditItem();
    await fetchAll();
  }
  async function deleteItem(item: GradeComponentItem) {
    const { error } = await supabase.from('grade_component_items').delete().eq('item_id', item.item_id);
    if (error) return showToastNotification('Error deleting item: ' + error.message, 'error');
    showToastNotification('Item deleted');
    await fetchAll();
  }


  // Grade Percentages actions (per component)

  function getPercentageForComponent(componentId: number): GradePercentage | undefined {

    return percentages.find((p) => p.component === componentId);

  }

  // Account management (no Supabase Auth). Manage current instructor via DB + localStorage
  interface Instructor { instructor_id: number; instructor_name: string; instructor_user_id: string }
  let instructors: Instructor[] = [];
  let selectedInstructorId: string | number = '';
  let nameDraft = '';
  let userIdDraft = '';
  let passwordDraft = '';
  let confirmPasswordDraft = '';

  function loadSelectedInstructorFromStorage() {
    const v = localStorage.getItem('current_instructor_id');
    if (v) selectedInstructorId = Number(v);
  }

  function persistSelectedInstructor() {
    if (selectedInstructorId) localStorage.setItem('current_instructor_id', String(selectedInstructorId));
  }

  async function loadInstructors() {
    const { data, error } = await supabase.from('instructor').select('instructor_id, instructor_name, instructor_user_id').order('instructor_name', { ascending: true });
    if (!error) instructors = data as any || [];
  }

  function syncNameDraft() {
    const inst = instructors.find(i => i.instructor_id === Number(selectedInstructorId));
    nameDraft = inst?.instructor_name || '';
    userIdDraft = inst?.instructor_user_id || '';
    passwordDraft = '';
    confirmPasswordDraft = '';
  }

  onMount(async () => {
    loadSelectedInstructorFromStorage();
    await loadInstructors();
    syncNameDraft();
  });

  function onChangeInstructor() {
    persistSelectedInstructor();
    syncNameDraft();
    isCreatingAccount = false;
  }


  async function saveAccount() {
    const id = Number(selectedInstructorId);
    const name = nameDraft.trim();
    const userId = userIdDraft.trim();

    if (!id || !name || !userId) return;

    const updateData: any = { instructor_name: name, instructor_user_id: userId };
    if (passwordDraft || confirmPasswordDraft) {
      if (passwordDraft !== confirmPasswordDraft) {
        showToastNotification('Passwords do not match', 'error');
        return;
      }
      if (passwordDraft.length < 6) {
        showToastNotification('Password must be at least 6 characters', 'error');
        return;
      }
      updateData.password = passwordDraft;
    }

    const { error } = await supabase.from('instructor').update(updateData).eq('instructor_id', id);
    if (!error) {
      showToastNotification('Account updated');
      await loadInstructors();
      syncNameDraft();
      isEditingAccount = false;
      passwordDraft = '';
      confirmPasswordDraft = '';
    } else {
      showToastNotification('Error updating account: ' + error.message, 'error');
    }

  }
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700"><Settings class="w-5 h-5" /> Settings</h2>
  <p class="mt-1 text-gray-500">Configure academic terms, grade components, and account settings.</p>
</section>

<hr class="my-4 border-gray-200" />

<main class="font-sans">
  <!-- Account Management -->
  <section class="bg-white rounded-lg border border-gray-200 p-6 mb-6">
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-bold text-gray-900">Account Management</h3>
    </div>

    <!-- Selection and Actions -->
    <div class="flex flex-col lg:flex-row gap-4 items-start lg:items-end mb-6">
      <div class="flex-1">
        <label class="block text-sm font-medium text-gray-700 mb-2">Select Instructor</label>
        <select class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" bind:value={selectedInstructorId} onchange={onChangeInstructor}>
          <option value="">Choose an instructor...</option>
          {#each instructors as inst}
            <option value={inst.instructor_id}>{inst.instructor_name}</option>
          {/each}
        </select>
      </div>
      <div class="flex gap-2">
        <button class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 font-medium hover:bg-gray-50 transition-colors" onclick={startNewAccount}>
          + New
        </button>
        <button class="px-4 py-2 bg-red-600 text-white text-sm rounded-lg font-medium hover:bg-red-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={deleteAccount} disabled={!selectedInstructorId}>
          Delete
        </button>
      </div>
    </div>

    <!-- Edit Form -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Instructor ID</label>
        <input class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 disabled:bg-gray-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. juan.dcruz" bind:value={userIdDraft} disabled={!isCreatingAccount && !isEditingAccount} />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Name</label>
        <input class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 disabled:bg-gray-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. Juan Dela Cruz" bind:value={nameDraft} disabled={!isCreatingAccount && !isEditingAccount} />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Password</label>
        <input type="password" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 disabled:bg-gray-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="••••••" bind:value={passwordDraft} disabled={!isCreatingAccount && !isEditingAccount} />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Confirm Password</label>
        <input type="password" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 disabled:bg-gray-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="••••••" bind:value={confirmPasswordDraft} disabled={!isCreatingAccount && !isEditingAccount} />
      </div>
    </div>

    <!-- Actions -->
    <div class="flex flex-wrap gap-2">
      {#if isCreatingAccount}
        <button class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 font-medium hover:bg-gray-50 transition-colors" onclick={cancelAccountEdit}>
          Cancel
        </button>
        <button class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-green-700 transition-colors" onclick={addAccount}>
          Add Account
        </button>
      {:else}
        {#if isEditingAccount}
          <button class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 font-medium hover:bg-gray-50 transition-colors" onclick={cancelAccountEdit}>
            Cancel
          </button>
          <button class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={saveAccount} disabled={!selectedInstructorId}>
            Save Changes
          </button>
        {:else}
          <button class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={() => (isEditingAccount = true)} disabled={!selectedInstructorId}>
            Edit Account
          </button>
        {/if}
      {/if}
    </div>
  </section>

  <!-- Academic Settings Group -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
    <!-- School Year -->
    <section class="bg-white rounded-lg border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-xl font-bold text-gray-900">School Year</h3>
      </div>

      <!-- Current Selection -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">Current School Year</label>
        <div class="flex gap-2">
          <select class="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" bind:value={selectedCurrentSY}>
            <option value="">Select school year...</option>
            {#each schoolYears as sy}
              <option value={sy.school_year_id}>{sy.school_year}</option>
            {/each}
          </select>
          <button class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg font-medium hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={setCurrentSchoolYear} disabled={loading}>
            Set Current
          </button>
        </div>
      </div>

      <!-- Add New -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">Add New School Year</label>
        <div class="flex gap-2">
          <input class="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. 2025-2026" bind:value={newSchoolYear} />
          <button class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={addSchoolYear} disabled={loading}>
            Add
          </button>
        </div>
      </div>

      <!-- School Years List -->
      {#if schoolYears.length > 0}
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Existing School Years</label>
          <div class="max-h-48 overflow-y-auto border border-gray-200 rounded-lg">
            {#each schoolYears as sy (sy.school_year_id)}
              <div class="px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 border-b border-gray-100 last:border-b-0">
                {sy.school_year}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </section>

    <!-- Terms -->
    <section class="bg-white rounded-lg border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-xl font-bold text-gray-900">Terms</h3>
      </div>

      <!-- Add/Edit Form -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">{editingTerm ? 'Edit Term' : 'New Term'}</label>
        <div class="flex gap-2">
          <input class="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. First Grading" bind:value={newTermName} />
          {#if editingTerm}
            <button class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 font-medium hover:bg-gray-50 transition-colors" onclick={cancelEditTerm}>
              Cancel
            </button>
          {/if}
          <button class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={saveTerm} disabled={loading}>
            {editingTerm ? 'Update' : 'Add'}
          </button>
        </div>
      </div>

      <!-- Terms Table -->
      <div class="overflow-x-auto rounded-lg border border-gray-200">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Term</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            {#if terms.length === 0}
              <tr>
                <td colspan="2" class="px-4 py-8 text-center text-sm text-gray-500">
                  No terms found. Add one above.
                </td>
              </tr>
            {:else}
              {#each terms as term (term.term_id)}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">{term.term_name}</td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium">
                    <button class="text-blue-600 hover:text-blue-900 mr-3 font-medium transition-colors" onclick={() => startEditTerm(term)}>
                      Edit
                    </button>
                    <button class="text-red-600 hover:text-red-900 font-medium transition-colors" onclick={() => deleteTerm(term)}>
                      Delete
                    </button>
                  </td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </section>
  </div>

  <!-- Grade Components -->
  <section class="bg-white rounded-lg border border-gray-200 p-6">
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-bold text-gray-900">Grade Components</h3>
    </div>

    <!-- Add/Edit Form -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">{editingComponent ? 'Edit Component' : 'Component Name'}</label>
        <input class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. Written Works" bind:value={newComponentName} />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Percentage</label>
        <input type="number" min="0" max="100" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-green-500" placeholder="e.g. 40" bind:value={newComponentPercentage} />
      </div>
      <div class="flex items-end gap-2">
        {#if editingComponent}
          <button class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 font-medium hover:bg-gray-50 transition-colors" onclick={cancelEditComponent}>
            Cancel
          </button>
        {/if}
        <button class="flex-1 px-4 py-2 bg-green-600 text-white text-sm rounded-lg font-medium hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors" onclick={saveComponent} disabled={loading}>
          {editingComponent ? 'Update' : 'Add'}
        </button>
      </div>
    </div>

    <!-- Components Table -->
    <div class="overflow-x-auto rounded-lg border border-gray-200">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Component Name</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Percentage</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200 bg-white">
          {#if components.length === 0}
            <tr>
              <td colspan="3" class="px-4 py-8 text-center text-sm text-gray-500">
                No components found. Add one above.
              </td>
            </tr>
          {:else}
            {#each components as c (c.component_id)}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">{c.component_name}</td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                  {getPercentageForComponent(c.component_id)?.percentage ?? 0}%
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm font-medium">
                  <button class="text-blue-600 hover:text-blue-900 mr-3 font-medium transition-colors" onclick={() => startEditComponent(c)}>
                    Edit
                  </button>
                  <button class="text-red-600 hover:text-red-900 font-medium transition-colors" onclick={() => deleteComponent(c)}>
                    Delete
                  </button>
                </td>
              </tr>
            {/each}
          {/if}
        </tbody>
      </table>
    </div>
  </section>
</main>

{#if showToast}
  <div class="fixed top-4 right-4 z-50">
    <Toast class="bg-white border border-gray-200 rounded-lg shadow-lg p-4 flex items-center gap-3 min-w-80" transition={fly} params={{ x: 200 }}>
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
